// swift-tools-version: 5.7
// Builds Apple's swift-openapi-generator at the exact revision that produced ton-api-swift 0.1.7.
import PackageDescription

let package = Package(
    name: "TonAPIGeneration",
    dependencies: [
        .package(url: "https://github.com/apple/swift-openapi-generator", exact: "0.3.1"),
        .package(url: "https://github.com/apple/swift-openapi-runtime", exact: "0.3.4")
    ],
    targets: []
)
