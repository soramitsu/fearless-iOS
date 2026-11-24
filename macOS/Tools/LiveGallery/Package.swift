// swift-tools-version: 6.0
// LiveGallery renders the app's screens offscreen over the LIVE wallet engine
// (real networks, a throwaway store) and checks address parity with the
// cross-platform vectors. It never submits a transaction.

import PackageDescription

let package = Package(
    name: "LiveGallery",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "../../Packages/WalletCore"),
        .package(path: "../../Packages/FearlessMacUI"),
        .package(path: "../../Packages/FearlessMacEngine")
    ],
    targets: [
        .executableTarget(
            name: "LiveGallery",
            dependencies: [
                .product(name: "WalletCore", package: "WalletCore"),
                .product(name: "WalletUI", package: "FearlessMacUI"),
                .product(name: "DesignSystem", package: "FearlessMacUI"),
                .product(name: "WalletEngine", package: "FearlessMacEngine")
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
