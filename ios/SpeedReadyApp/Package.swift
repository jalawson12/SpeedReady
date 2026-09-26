// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SpeedReadyApp",
    platforms: [
        .iOS(.v17)
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
            path: "Sources/SpeedReadyApp",
            exclude: [
                "App",
                "Views",
                "Services/DocumentImportService.swift"
            ]
        ),
        .testTarget(
            name: "SpeedReadyAppTests",
            dependencies: ["SpeedReadyApp"],
            path: "Tests/SpeedReadyAppTests"
        )
    ]
)
