public enum MachPortError: Error {
  case failedToCreateMachPort
  case failedToCreateKeyCode(Int)
  case failedToCreateEvent
}
