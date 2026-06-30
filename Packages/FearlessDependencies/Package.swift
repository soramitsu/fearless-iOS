// swift-tools-version:5.9
import PackageDescription

// Aggregator package to pin and unify external SPM dependencies used by the app.
// Keep versions in sync with Xcode project pins and CI.

let package = Package(
    name: "FearlessDependencies",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(name: "FearlessDependencies", targets: ["FearlessDependencies"])
    ],
    dependencies: [
        // Reown (WalletConnect successor)
        .package(url: "https://github.com/reown-com/reown-swift", from: "1.0.0"),
        // Web3
        .package(url: "https://github.com/soramitsu/web3-swift", exact: "7.7.7"),
        // Explicitly add BigInt to satisfy transitive usage in SSFModels under explicit module builds
        .package(url: "https://github.com/attaswift/BigInt.git", from: "5.3.0"),
        // UI helpers
        .package(url: "https://github.com/evgenyneu/Cosmos.git", exact: "25.0.1"),
        .package(url: "https://github.com/sendyhalim/Swime", from: "3.1.0"),
        // Logging + reachability (migrated from CocoaPods)
        .package(url: "https://github.com/SwiftyBeaver/SwiftyBeaver.git", exact: "2.1.1"),
        .package(url: "https://github.com/ashleymills/Reachability.swift", exact: "5.2.4"),
        // Image loading and layout (migrated from CocoaPods)
        .package(url: "https://github.com/onevcat/Kingfisher", exact: "7.10.2"),
        .package(url: "https://github.com/SnapKit/SnapKit", exact: "5.0.0"),
        // TON SDK + remote API
        .package(url: "https://github.com/tonkeeper/ton-api-swift.git", exact: "0.1.7"),
        .package(url: "https://github.com/tonkeeper/ton-swift.git", exact: "1.0.4"),
        .package(url: "https://github.com/apple/swift-openapi-runtime", exact: "0.3.6"),
        .package(url: "https://github.com/apple/swift-http-types", exact: "1.5.1")
    ],
    targets: [
        .target(
            name: "FearlessDependencies",
            dependencies: [
                // Reown products (module names are compatible with WalletConnect v2)
                .product(name: "WalletConnect", package: "reown-swift"),
                .product(name: "WalletConnectNetworking", package: "reown-swift"),
                .product(name: "WalletConnectPairing", package: "reown-swift"),
                .product(name: "ReownWalletKit", package: "reown-swift"),
                // Web3 products
                .product(name: "Web3", package: "web3-swift"),
                .product(name: "Web3ContractABI", package: "web3-swift"),
                .product(name: "Web3PromiseKit", package: "web3-swift"),
                // Numeric helpers
                .product(name: "BigInt", package: "BigInt"),
                // UI helpers
                .product(name: "Cosmos", package: "Cosmos"),
                .product(name: "Swime", package: "Swime"),
                // Logging + reachability
                .product(name: "SwiftyBeaver", package: "SwiftyBeaver"),
                .product(name: "Reachability", package: "Reachability.swift"),
                // Image loading and layout
                .product(name: "Kingfisher", package: "Kingfisher"),
                .product(name: "SnapKit", package: "SnapKit"),
                // TON SDK
                .product(name: "TonAPI", package: "ton-api-swift"),
                .product(name: "TonSwift", package: "ton-swift"),
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "HTTPTypes", package: "swift-http-types")
            ],
            path: "Sources/FearlessDependencies"
        )
    ]
)
