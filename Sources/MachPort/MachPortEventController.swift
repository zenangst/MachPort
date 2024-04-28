import Carbon
import Cocoa
import os

public class MachPortEventPublisher {
  @Published public internal(set) var flagsChanged: CGEventFlags?
  @Published public internal(set) var event: MachPortEvent?

  required init() throws {}
}

public final class MachPortEventController: MachPortEventPublisher, @unchecked Sendable {
  private(set) public var eventSource: CGEventSource!

  private var previousId: UUID?
  private var machPort: CFMachPort?
  private var runLoopSource: CFRunLoopSource?
  private static var lhs: Bool = true
  private var currentMode: CFRunLoopMode = .commonModes
  public var onEventChange: ((MachPortEvent) -> Void)? = nil
  public var onFlagsChanged: ((MachPortEvent) -> Void)? = nil
  public var onAllEventChange: ((MachPortEvent) -> Void)? = nil

  private let eventsOfInterest: CGEventMask
  private let eventSourceId: CGEventSourceStateID
  private let signature: Int64
  private let configuration: MachPortTapConfiguration

  public var isEnabled: Bool {
    get { machPort.map(CGEvent.tapIsEnabled) ?? false }
    set { machPort.map { CGEvent.tapEnable(tap: $0, enable: newValue) } }
  }

  required public init(_ eventSourceId: CGEventSourceStateID,
                       eventsOfInterest: CGEventMask? = nil,
                       signature: String,
                       configuration: MachPortTapConfiguration = .init(),
                       autoStartMode: CFRunLoopMode? = .commonModes,
                       onAllEventChange: ((MachPortEvent) -> Void)? = nil,
                       onFlagsChanged: ((MachPortEvent) -> Void)? = nil,
                       onEventChange: ((MachPortEvent) -> Void)? = nil) throws {
    if let eventsOfInterest {
      self.eventsOfInterest = eventsOfInterest
    } else {
      self.eventsOfInterest = 1 << CGEventType.keyDown.rawValue
      | 1 << CGEventType.keyUp.rawValue
      | 1 << CGEventType.flagsChanged.rawValue
    }
    self.eventSourceId = eventSourceId
    self.signature = Int64(signature.hashValue)
    self.configuration = configuration
    self.onEventChange = onEventChange
    self.onFlagsChanged = onFlagsChanged
    self.onAllEventChange = onAllEventChange
    try super.init()
    if let autoStartMode { try start(mode: autoStartMode) }
  }


  required init() throws {
    fatalError("init() has not been implemented")
  }

  // MARK: Public methods

  public func start(in runLoop: CFRunLoop = CFRunLoopGetCurrent(),
                    mode: CFRunLoopMode) throws {
    let machPort = try createMachPort(mode)
    self.eventSource = try CGEventSource.create(eventSourceId)
    self.machPort = machPort
    self.currentMode = mode
    self.runLoopSource = try CFRunLoopSource.create(with: machPort)

    CFRunLoopAddSource(runLoop, runLoopSource, mode)
  }

  public func stop(in runLoop: CFRunLoop = CFRunLoopGetMain(), mode: CFRunLoopMode) {
    CFRunLoopRemoveSource(runLoop, runLoopSource, mode)
    guard let machPort else { return }
    CFMachPortInvalidate(machPort)
    self.runLoopSource = nil
  }

  public func reload(in runLoop: CFRunLoop = CFRunLoopGetCurrent(),
                     mode: CFRunLoopMode) throws {
    guard let machPort else {
      stop(mode: mode)
      try start(mode: mode)
      return
    }
    CGEvent.tapEnable(tap: machPort, enable: true)
  }

  public func createEvent(_ key: Int, type: CGEventType, flags: CGEventFlags,
                          tapLocation: CGEventTapLocation = .cghidEventTap,
                          configure: (CGEvent) -> Void = { _ in }) throws -> CGEvent {
    guard let cgKeyCode = CGKeyCode(exactly: key) else {
      throw MachPortError.failedToCreateKeyCode(key)
    }

    guard let cgEvent = CGEvent(keyboardEventSource: eventSource,
                                virtualKey: cgKeyCode,
                                keyDown: type == .keyDown) else {
      throw MachPortError.failedToCreateEvent
    }

    cgEvent.setIntegerValueField(.eventSourceUserData, value: signature)
    cgEvent.flags = flags

    configure(cgEvent)

    return cgEvent
  }

  @discardableResult
  public func post(_ key: Int, type: CGEventType, flags: CGEventFlags,
                   tapLocation: CGEventTapLocation = .cghidEventTap,
                   configure: (CGEvent) -> Void = { _ in }) throws -> CGEvent {
    let cgEvent = try createEvent(key, type: type, flags: flags,
                                  tapLocation: tapLocation, configure: configure)

    cgEvent.post(tap: tapLocation)

    return cgEvent
  }

  public func post(mouseButton: CGMouseButton,
                   mouseType: CGEventType,
                   tapLocation: CGEventTapLocation = .cghidEventTap,
                   clickCount: Int64 = 1,
                   location: CGPoint) {
    guard let cgEvent = CGEvent(
      mouseEventSource: eventSource,
      mouseType: mouseType,
      mouseCursorPosition: location,
      mouseButton: mouseButton
    ) else {
      return
    }
    cgEvent.setIntegerValueField(.eventSourceUserData, value: signature)
    if clickCount > 1 {
      cgEvent.setIntegerValueField(.mouseEventClickState, value: clickCount)
    }

    cgEvent.post(tap: tapLocation)
  }

  // MARK: Private methods

  private final func callback(_ proxy: CGEventTapProxy, _ type: CGEventType,
                              _ cgEvent: CGEvent) -> Unmanaged<CGEvent>? {
    if cgEvent.getIntegerValueField(.eventSourceUserData) == signature {
      return Unmanaged.passUnretained(cgEvent)
    }

    let isRepeat = cgEvent.getIntegerValueField(.keyboardEventAutorepeat) == 1
    let id: UUID

    switch cgEvent.type {
    case .keyUp:
      if let previousId {
        id = previousId
      } else {
        id = UUID()
      }
      previousId = nil
    case .keyDown:
      if isRepeat, let previousId {
        id = previousId
      } else {
        id = UUID()
        previousId = id
      }
    default:
      previousId = nil
      id = UUID()
    }

    let result = Unmanaged.passUnretained(cgEvent)
    let newEvent = MachPortEvent(
      id: id,
      event: cgEvent, eventSource: eventSource,
      isRepeat: isRepeat,
      lhs: Self.lhs, type: type,
      result: result)

    if let onAllEventChange {
      if type == .flagsChanged {
        Self.lhs = determineModifierKeysLocation(cgEvent)
      }
      onAllEventChange(newEvent)
      return newEvent.result
    }

    if type == .flagsChanged {
      Self.lhs = determineModifierKeysLocation(cgEvent)
      if let onFlagsChanged {
        onFlagsChanged(newEvent)
      } else {
        flagsChanged = cgEvent.flags
      }
      return newEvent.result
    }

    if let onEventChange {
      onEventChange(newEvent)
    } else {
      event = newEvent
    }
    return newEvent.result
  }

  private final func determineModifierKeysLocation(_ cgEvent: CGEvent) -> Bool {
    var result: Bool = true
    let emptyFlags = cgEvent.flags == CGEventFlags.maskNonCoalesced

    if !emptyFlags {
      let keyCode = cgEvent.getIntegerValueField(.keyboardEventKeycode)

      // Always return `true` if the function key is involved
      if keyCode == kVK_Function {
        return true
      }

      let rhs: Set<Int> = [kVK_RightCommand, kVK_RightOption, kVK_RightShift]
      result = !rhs.contains(Int(keyCode))
    } else if emptyFlags {
      result = true
    }

    return result
  }

  private final func createMachPort(_ currentMode: CFRunLoopMode) throws -> CFMachPort {
    let userInfo = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

    guard let machPort = CGEvent.tapCreate(
      tap: configuration.location,
      place: configuration.place,
      options: configuration.options,
      eventsOfInterest: eventsOfInterest,
      callback: { proxy, type, event, userInfo in
        if let pointer = userInfo {
          let controller = Unmanaged<MachPortEventController>
            .fromOpaque(pointer)
            .takeUnretainedValue()
          if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            try? controller.reload(mode: controller.currentMode)
            return Unmanaged.passUnretained(event)
          } else {
            return controller.callback(proxy, type, event)
          }
        }
        return Unmanaged.passUnretained(event)
      }, userInfo: userInfo) else {
      throw MachPortError.failedToCreateMachPort
    }
    return machPort
  }
}
