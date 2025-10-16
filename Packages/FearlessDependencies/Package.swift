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
        // WalletConnect v2 stack
        .package(url: "https://github.com/WalletConnect/WalletConnectSwiftV2", exact: "1.20.3"),
        // Web3
        .package(url: "https://github.com/soramitsu/web3-swift", exact: "7.7.7"),
        // UI helpers
        .package(url: "https://github.com/evgenyneu/Cosmos.git", exact: "25.0.1"),
        .package(url: "https://github.com/sendyhalim/Swime", from: "3.1.0"),
        // Logging + reachability (migrated from CocoaPods)
        .package(url: "https://github.com/SwiftyBeaver/SwiftyBeaver.git", exact: "2.1.1"),
        .package(url: "https://github.com/ashleymills/Reachability.swift", exact: "5.2.4"),
        // Image loading and layout (migrated from CocoaPods)
        .package(url: "https://github.com/onevcat/Kingfisher", exact: "7.10.2"),
        .package(url: "https://github.com/SnapKit/SnapKit", exact: "5.0.0"),
    ],
    targets: [
        .target(
            name: "FearlessDependencies",
            dependencies: [
                // WalletConnect products (align with 1.20.x manifest)
                .product(name: "WalletConnect", package: "WalletConnectSwiftV2"),
                .product(name: "WalletConnectNetworking", package: "WalletConnectSwiftV2"),
                .product(name: "WalletConnectPairing", package: "WalletConnectSwiftV2"),
                .product(name: "Web3Wallet", package: "WalletConnectSwiftV2"),
                // Web3 products
                .product(name: "Web3", package: "web3-swift"),
                .product(name: "Web3ContractABI", package: "web3-swift"),
                .product(name: "Web3PromiseKit", package: "web3-swift"),
                // UI helpers
                .product(name: "Cosmos", package: "Cosmos"),
                .product(name: "Swime", package: "Swime"),
                // Logging + reachability
                .product(name: "SwiftyBeaver", package: "SwiftyBeaver"),
                .product(name: "Reachability", package: "Reachability.swift"),
                // Image loading and layout
                .product(name: "Kingfisher", package: "Kingfisher"),
                .product(name: "SnapKit", package: "SnapKit"),
            ],
            path: "Sources/FearlessDependencies"
        )
    ]
)
