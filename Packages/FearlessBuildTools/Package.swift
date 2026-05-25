// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FearlessBuildTools",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "ci-keys-generator", targets: ["CIKeysGenerator"])
    ],
    dependencies: [
        .package(url: "https://github.com/mac-cain13/R.swift.git", exact: "6.1.0"),
        .package(url: "https://github.com/nicklockwood/SwiftFormat.git", exact: "0.47.13"),
        .package(url: "https://github.com/realm/SwiftLint.git", from: "0.62.1")
    ],
    targets: [
        .target(name: "CIKeysGeneratorCore"),
        .executableTarget(
            name: "CIKeysGenerator",
            dependencies: ["CIKeysGeneratorCore"]
        ),
        .testTarget(
            name: "CIKeysGeneratorCoreTests",
            dependencies: ["CIKeysGeneratorCore"]
        )
    ]
)
