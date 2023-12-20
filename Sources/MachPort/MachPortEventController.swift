import Carbon
import Cocoa
import os

public class MachPortEventPublisher {
  @Published public internal(set) var flagsChanged: CGEventFlags?
  @Published public internal(set) var event: MachPortEvent?

  required init() throws {}
}


public final class MachPortEventController: MachPortEventPublisher {
  private(set) public var eventSource: CGEventSource!

  private var machPort: CFMachPort?
  private var runLoopSource: CFRunLoopSource?
  private var lhs: Bool = true
  private var currentMode: CFRunLoopMode = .commonModes

  private let eventSourceId: CGEventSourceStateID
  private let signature: Int64
  private let configuration: MachPortTapConfiguration

  public var isEnabled: Bool {
    get { machPort.map(CGEvent.tapIsEnabled) ?? false }
    set { machPort.map { CGEvent.tapEnable(tap: $0, enable: newValue) } }
  }

  required public init(_ eventSourceId: CGEventSourceStateID,
                       signature: String,
                       configuration: MachPortTapConfiguration = .init(),
                       autoStartMode: CFRunLoopMode? = .commonModes) throws {
    self.eventSourceId = eventSourceId
    self.signature = Int64(signature.hashValue)
    self.configuration = configuration
    try super.init()
    if let autoStartMode { try start(mode: autoStartMode) }
  }


  required init() throws {
    fatalError("init() has not been implemented")
  }

  // MARK: Public methods

  public func start(in runLoop: CFRunLoop = CFRunLoopGetMain(),
                    mode: CFRunLoopMode) throws {
    let machPort = try createMachPort()
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

  public func reload(in runLoop: CFRunLoop = CFRunLoopGetMain(),
                     mode: CFRunLoopMode) throws {
    stop(mode: mode)
    try start(mode: mode)
  }

  public func post(_ key: Int, type: CGEventType, flags: CGEventFlags,
                   tapLocation: CGEventTapLocation = .cghidEventTap,
                   configure: (CGEvent) -> Void = { _ in }) throws {
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

    cgEvent.post(tap: tapLocation)
  }

  // MARK: Private methods

  private func callback(_ proxy: CGEventTapProxy, _ type: CGEventType,
                        _ cgEvent: CGEvent) -> Unmanaged<CGEvent>? {
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
      try? reload(mode: currentMode)
    }

    let result: Unmanaged<CGEvent>? = Unmanaged.passUnretained(cgEvent)
    if cgEvent.getIntegerValueField(.eventSourceUserData) == signature {
      return result
    }

    if type == .flagsChanged {
      self.lhs = determineModifierKeysLocation(cgEvent)
      flagsChanged = cgEvent.flags
      return result
    }

    let newEvent = MachPortEvent(event: cgEvent, eventSource: eventSource,
                                 lhs: self.lhs,
                                 type: type, result: result)

    event = newEvent

    return newEvent.result
  }

  private func determineModifierKeysLocation(_ cgEvent: CGEvent) -> Bool {
    var result: Bool = true
    let emptyFlags = cgEvent.flags == CGEventFlags.maskNonCoalesced

    if !emptyFlags {
      let keyCode = cgEvent.getIntegerValueField(.keyboardEventKeycode)

      // Always return `true` if the function key is involved
      if keyCode == kVK_Function {
        return true
      }

      let rhs: [Int] = [kVK_RightCommand, kVK_RightOption, kVK_RightShift]
      result = !rhs.contains(Int(keyCode))
    } else if emptyFlags {
      result = true
    }

    return result
  }

  private func createMachPort() throws -> CFMachPort {
    let mask: CGEventMask = 1 << CGEventType.keyDown.rawValue
    | 1 << CGEventType.keyUp.rawValue
    | 1 << CGEventType.flagsChanged.rawValue
    let userInfo = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

    guard let machPort = CGEvent.tapCreate(
      tap: configuration.location,
      place: configuration.place,
      options: configuration.options,
      eventsOfInterest: mask,
      callback: { proxy, type, event, userInfo in
        if let pointer = userInfo {
          let controller = Unmanaged<MachPortEventController>
            .fromOpaque(pointer)
            .takeUnretainedValue()
          return controller.callback(proxy, type, event)
        }
        return Unmanaged.passUnretained(event)
      }, userInfo: userInfo) else {
      throw MachPortError.failedToCreateMachPort
    }
    return machPort
  }
}
