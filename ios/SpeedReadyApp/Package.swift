// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "SpeedReadyApp",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        .library(
            name: "SpeedReadyApp",
            targets: ["SpeedReadyApp"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.19")
    ],
    targets: [
        .target(
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
    ],
    swiftLanguageModes: [.v6]
)
