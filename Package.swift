// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "CodexSpeed",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(name: "CodexSpeedCore", targets: ["CodexSpeedCore"]),
        .executable(name: "CodexSpeed", targets: ["CodexSpeedApp"]),
        .executable(name: "CodexSpeedCoreTests", targets: ["CodexSpeedCoreTests"]),
    ],
    targets: [
        .target(name: "CodexSpeedCore"),
        .executableTarget(
            name: "CodexSpeedApp",
            dependencies: ["CodexSpeedCore"]
        ),
        .executableTarget(
            name: "CodexSpeedCoreTests",
            dependencies: ["CodexSpeedCore"],
            path: "Tests/CodexSpeedCoreTests"
        ),
    ]
)
