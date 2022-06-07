// swift-tools-version:5.6
import PackageDescription

let package = Package(
  name: "MachPort",
  platforms: [.macOS(.v10_15)],
  products: [
    .library(name: "MachPort", targets: ["MachPort"]),
  ],
  targets: [
    .target(
      name: "MachPort",
      dependencies: [])
  ]
)

