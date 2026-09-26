// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SpeedReadyApp",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .executable(
            name: "SpeedReadyApp",
            targets: ["SpeedReadyApp"]
        )
    ],
    targets: [
        .executableTarget(
            name: "SpeedReadyApp",
            path: "Sources/SpeedReadyApp"
        )
    ]
)
