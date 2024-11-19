import CoreGraphics

internal extension CGEventSource {
  static func create(_ stateID: CGEventSourceStateID) throws(MachPortError) -> CGEventSource {
    guard let eventSource = CGEventSource(stateID: stateID) else {
      throw .failedToCreateCGEventSource
    }
    return eventSource
  }
}
