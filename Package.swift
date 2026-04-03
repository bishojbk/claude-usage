// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "ClaudeUsage",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "ClaudeUsage",
            path: "ClaudeUsage",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "ClaudeUsageTests",
            dependencies: ["ClaudeUsage"],
            path: "ClaudeUsageTests"
        )
    ]
)
