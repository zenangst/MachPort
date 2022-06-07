import CoreGraphics

public struct MachPortTapConfiguration {
  internal let location: CGEventTapLocation
  internal let place: CGEventTapPlacement
  internal let options: CGEventTapOptions

  init(location: CGEventTapLocation = .cgSessionEventTap,
       placement: CGEventTapPlacement = .headInsertEventTap,
       options: CGEventTapOptions = .defaultTap) {
    self.location = location
    self.place = placement
    self.options = options
  }
}
