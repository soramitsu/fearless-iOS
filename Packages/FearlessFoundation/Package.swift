// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FearlessFoundation",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(name: "FearlessFoundation", targets: ["FearlessFoundation"])
    ],
    dependencies: [
        .package(path: "../FearlessSecureStorage")
    ],
    targets: [
        .target(
            name: "FearlessFoundation",
            dependencies: [
                .product(name: "FearlessSecureStorage", package: "FearlessSecureStorage")
            ],
            path: "Sources/FearlessFoundation"
        ),
        .testTarget(
            name: "FearlessFoundationTests",
            dependencies: [
                "FearlessFoundation",
                .product(name: "FearlessSecureStorage", package: "FearlessSecureStorage")
            ],
            path: "Tests/FearlessFoundationTests"
        )
    ]
)
