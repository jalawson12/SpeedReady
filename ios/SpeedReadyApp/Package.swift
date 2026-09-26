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
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.19")
    ],
    targets: [
        .executableTarget(
            name: "SpeedReadyApp",
            dependencies: [
                .product(name: "ZIPFoundation", package: "ZIPFoundation")
            ],
            path: "Sources/SpeedReadyApp"
        ),
        .testTarget(
            name: "SpeedReadyAppTests",
            dependencies: ["SpeedReadyApp"],
            path: "Tests/SpeedReadyAppTests"
        )
    ]
)
