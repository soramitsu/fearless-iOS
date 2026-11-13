// swift-tools-version: 5.7
// The tonapi.io REST client, generated in this repository from the MIT-licensed opentonapi
// specification in `openapi/`. See README.md for provenance and `scripts/deps/regenerate-tonapi.sh`.
import PackageDescription

let package = Package(
    name: "TonAPI",
    platforms: [
        .macOS(.v12), .iOS(.v13)
    ],
    products: [
        .library(name: "TonAPI", targets: ["TonAPI"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-openapi-runtime", exact: "0.3.6"),
        .package(url: "https://github.com/apple/swift-http-types", exact: "1.5.1")
    ],
    targets: [
        .target(
            name: "TonAPI",
            dependencies: [
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "HTTPTypes", package: "swift-http-types")
            ]
        )
    ]
)
