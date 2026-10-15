// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BatteryToy",
    platforms: [.macOS(.v14), .iOS(.v18)],
    products: [.library(name: "BatteryCore", targets: ["BatteryCore"])],
    targets: [
        .target(name: "BatteryCore"),
        .testTarget(name: "BatteryCoreTests", dependencies: ["BatteryCore"])
    ]
)
