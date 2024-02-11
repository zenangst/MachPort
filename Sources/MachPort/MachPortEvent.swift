import CoreGraphics
import Foundation

public final class MachPortEvent: @unchecked Sendable {
  public let keyCode: Int64
  public let event: CGEvent
  public let eventSource: CGEventSource?
  public let type: CGEventType
  public let lhs: Bool
  public var result: Unmanaged<CGEvent>?

  internal init(event: CGEvent, eventSource: CGEventSource?,
                lhs: Bool, type: CGEventType, result: Unmanaged<CGEvent>?) {
    self.keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    self.event = event
    self.eventSource = eventSource
    self.lhs = lhs
    self.type = type
    self.result = result
  }

  public static func empty() -> MachPortEvent? {
    guard let event = CGEvent(source: nil) else { return nil }
    return MachPortEvent(event: event, eventSource:  nil, lhs:  false, type:  .null, result: nil)
  }
}
