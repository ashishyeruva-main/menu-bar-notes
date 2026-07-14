// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MenuBarNotes",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "MenuBarNotes",
            path: "Sources/MenuBarNotes"
        )
    ]
)
