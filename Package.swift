// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TaskPad",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "TaskPad", targets: ["TaskPad"])],
    targets: [
        .target(name: "TaskPadCore"),
        .executableTarget(name: "TaskPad", dependencies: ["TaskPadCore"]),
        .testTarget(name: "TaskPadCoreTests", dependencies: ["TaskPadCore"]),
        .testTarget(name: "TaskPadAppTests", dependencies: ["TaskPad", "TaskPadCore"])
    ]
)
