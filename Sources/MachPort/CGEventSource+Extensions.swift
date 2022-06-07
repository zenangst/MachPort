import CoreGraphics

public enum CGEventSourceError: Error {
  case failedToCreateCGEventSource
}

internal extension CGEventSource {
  static func create(_ stateID: CGEventSourceStateID) throws -> CGEventSource {
    guard let eventSource = CGEventSource(stateID: stateID) else {
      throw CGEventSourceError.failedToCreateCGEventSource
    }
    return eventSource
  }
}
