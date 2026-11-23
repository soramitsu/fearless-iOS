// swift-tools-version: 6.0
// FearlessMacUI: the macOS interface of Fearless Wallet. It talks to the
// wallet only through WalletCore's service protocols.

import PackageDescription

let package = Package(
    name: "FearlessMacUI",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "WalletUI", targets: ["WalletUI"]),
        .library(name: "WalletPreviewSupport", targets: ["WalletPreviewSupport"]),
        .executable(name: "FearlessMacDemo", targets: ["FearlessMacDemo"]),
        .executable(name: "FearlessMacSnapshots", targets: ["FearlessMacSnapshots"])
    ],
    dependencies: [
        .package(path: "../WalletCore")
    ],
    targets: [
        // Brand tokens, typography and reusable components.
        .target(
            name: "DesignSystem",
            dependencies: ["WalletCore"],
            resources: [
                .copy("Resources/Fonts"),
                .copy("Resources/Icons"),
                .copy("Resources/Brand")
            ]
        ),
        // Screens, view models, navigation, commands and scenes.
        .target(
            name: "WalletUI",
            dependencies: ["WalletCore", "DesignSystem"]
        ),
        // In-memory services with sample data for previews, the demo app,
        // snapshots and tests. Never linked into the shipping app.
        .target(
            name: "WalletPreviewSupport",
            dependencies: ["WalletCore"],
            resources: [
                .copy("Resources/bip39-english.txt")
            ]
        ),
        // Xcode canvas previews of the main screens.
        .target(
            name: "WalletUIPreviews",
            dependencies: ["WalletUI", "WalletPreviewSupport", "DesignSystem"]
        ),
        // Runs the interface with sample data, without the engine.
        .executableTarget(
            name: "FearlessMacDemo",
            dependencies: ["WalletUI", "WalletPreviewSupport"]
        ),
        // Renders every main screen to PNG files for review.
        .executableTarget(
            name: "FearlessMacSnapshots",
            dependencies: ["WalletUI", "WalletPreviewSupport", "DesignSystem"]
        ),
        .testTarget(
            name: "WalletUITests",
            dependencies: ["WalletUI", "WalletPreviewSupport", "DesignSystem"]
        )
    ],
    swiftLanguageModes: [.v6]
)
