// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TrackApp",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "TrackApp",
            path: "Sources/TrackApp"
        )
    ]
)
