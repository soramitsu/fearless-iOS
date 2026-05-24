// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FearlessSecureStorage",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(name: "FearlessSecureStorage", targets: ["FearlessSecureStorage"])
    ],
    targets: [
        .target(
            name: "FearlessSecureStorage",
            path: "Sources/FearlessSecureStorage"
        ),
        .testTarget(
            name: "FearlessSecureStorageTests",
            dependencies: ["FearlessSecureStorage"],
            path: "Tests/FearlessSecureStorageTests"
        )
    ]
)
