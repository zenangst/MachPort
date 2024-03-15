import CoreGraphics
import Foundation

public final class MachPortEvent: @unchecked Sendable {
  public let id: UUID
  public let keyCode: Int64
  public let event: CGEvent
  public let eventSource: CGEventSource?
  public let isRepeat: Bool
  public let type: CGEventType
  public let lhs: Bool
  public var result: Unmanaged<CGEvent>?

  internal init(id: UUID,
                event: CGEvent, eventSource: CGEventSource?,
                isRepeat: Bool, lhs: Bool, type: CGEventType,
                result: Unmanaged<CGEvent>?) {
    self.id = id
    self.keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    self.isRepeat = isRepeat
    self.event = event
    self.eventSource = eventSource
    self.lhs = lhs
    self.type = type
    self.result = result
  }

  public static func empty() -> MachPortEvent? {
    guard let event = CGEvent(source: nil) else { return nil }
    return MachPortEvent(
      id: UUID(),
      event: event,
      eventSource:  nil,
      isRepeat: false,
      lhs:  false,
      type:  .null,
      result: nil
    )
  }
}
