// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FearlessUI",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(name: "FearlessUI", targets: ["FearlessUI"])
    ],
    targets: [
        .target(
            name: "FearlessUI",
            path: "Sources/FearlessUI"
        ),
        .testTarget(
            name: "FearlessUITests",
            dependencies: ["FearlessUI"],
            path: "Tests/FearlessUITests"
        )
    ]
)
