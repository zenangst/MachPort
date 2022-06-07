import CoreFoundation

public enum CFRunLoopSourceError: Error {
  case failedToCreateCFRunLoopSource
}

internal extension CFRunLoopSource {
  static func create(with machPort: CFMachPort) throws -> CFRunLoopSource {
    guard let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, machPort, 0) else {
      throw CFRunLoopSourceError.failedToCreateCFRunLoopSource
    }
    return runLoopSource
  }
}
