// swift-tools-version: 6.0
// WalletCore is the dependency-free contract between the Fearless macOS UI
// (FearlessMacUI) and the wallet engine (FearlessMacEngine).

import PackageDescription

let package = Package(
    name: "WalletCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "WalletCore", targets: ["WalletCore"])
    ],
    targets: [
        .target(name: "WalletCore"),
        .testTarget(name: "WalletCoreTests", dependencies: ["WalletCore"])
    ]
)
