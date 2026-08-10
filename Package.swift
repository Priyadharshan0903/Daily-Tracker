// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Daybook",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Daybook",
            path: "Sources/Daybook"
        )
    ]
)
