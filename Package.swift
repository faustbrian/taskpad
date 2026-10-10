// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Taskpad",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Taskpad", targets: ["Taskpad"])],
    targets: [
        .target(name: "TaskpadCore"),
        .executableTarget(name: "Taskpad", dependencies: ["TaskpadCore"]),
        .testTarget(name: "TaskpadCoreTests", dependencies: ["TaskpadCore"]),
        .testTarget(name: "TaskpadAppTests", dependencies: ["Taskpad", "TaskpadCore"])
    ]
)
