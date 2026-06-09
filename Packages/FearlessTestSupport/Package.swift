// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FearlessTestSupport",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(name: "FearlessTestSupport", targets: ["FearlessTestSupport"])
    ],
    targets: [
        .target(
            name: "FearlessTestSupport",
            path: "Sources/FearlessTestSupport"
        ),
        .testTarget(
            name: "FearlessTestSupportTests",
            dependencies: ["FearlessTestSupport"],
            path: "Tests/FearlessTestSupportTests",
            resources: [
                .process("Fixtures")
            ]
        )
    ]
)
