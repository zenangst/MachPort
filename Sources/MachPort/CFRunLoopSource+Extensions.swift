import CoreFoundation

internal extension CFRunLoopSource {
  static func create(with machPort: CFMachPort) throws(MachPortError) -> CFRunLoopSource {
    guard let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, machPort, 0) else {
      throw .failedToCreateCFRunLoopSource
    }
    return runLoopSource
  }
}
