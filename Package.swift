// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "OptSwitch",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "OptSwitch", path: "Sources/OptSwitch"),
    ]
)
