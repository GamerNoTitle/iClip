// swift-tools-version: 6.0
import PackageDescription
import Foundation

var targets: [Target] = [
    .target(name: "iClipCore"),
    .target(name: "iClipPlatform", dependencies: ["iClipCore"]),
    .executableTarget(name: "iClip", dependencies: ["iClipCore", "iClipPlatform"], resources: [.process("Resources")])
]

// Packaging checkouts may intentionally omit Tests. Never register missing targets.
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
if ProcessInfo.processInfo.environment["ICLIP_INCLUDE_TESTS"] != "0" {
    for (name, dependencies) in [
        ("iClipCoreTests", ["iClipCore"]),
        ("iClipPlatformTests", ["iClipCore", "iClipPlatform"])
    ] {
        let directory = root.appendingPathComponent("Tests/\(name)")
        if FileManager.default.fileExists(atPath: directory.path) {
            targets.append(.testTarget(name: name, dependencies: dependencies.map { .byName(name: $0) }))
        }
    }
}

let package = Package(
    name: "iClip",
    defaultLocalization: "zh-Hans",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "iClip", targets: ["iClip"])],
    targets: targets
)
