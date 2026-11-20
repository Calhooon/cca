// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ClaudeAccountsBar",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "ClaudeAccountsBar",
            path: "Sources/ClaudeAccountsBar"
        )
    ]
)
