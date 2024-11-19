// swift-tools-version:6.0
import PackageDescription

let package = Package(
  name: "MachPort",
  platforms: [.macOS(.v10_15)],
  products: [
    .library(name: "MachPort", targets: ["MachPort"]),
  ],
  targets: [
    .target(name: "MachPort", dependencies: [])
  ]
)

