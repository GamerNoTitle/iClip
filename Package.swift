// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "iClip",
    defaultLocalization: "zh-Hans",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "iClip", targets: ["iClip"])],
    targets: [
        .target(name: "iClipCore"),
        .target(name: "iClipPlatform", dependencies: ["iClipCore"]),
        .executableTarget(name: "iClip", dependencies: ["iClipCore", "iClipPlatform"], resources: [.process("Resources")]),
        .testTarget(name: "iClipCoreTests", dependencies: ["iClipCore"]),
        .testTarget(name: "iClipPlatformTests", dependencies: ["iClipCore", "iClipPlatform"])
    ]
)
