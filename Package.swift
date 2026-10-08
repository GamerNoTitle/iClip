// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "iClip",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "iClip", targets: ["iClip"])],
    targets: [
        .target(name: "iClipCore"),
        .target(name: "iClipPlatform", dependencies: ["iClipCore"]),
        .executableTarget(name: "iClip", dependencies: ["iClipCore", "iClipPlatform"]),
        .testTarget(name: "iClipCoreTests", dependencies: ["iClipCore"]),
        .testTarget(name: "iClipPlatformTests", dependencies: ["iClipCore", "iClipPlatform"])
    ]
)
