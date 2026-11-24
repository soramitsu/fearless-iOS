// swift-tools-version:5.9
import PackageDescription

// Fearless's own WalletConnect v2 client (wallet role). It replaced Reown's reown-swift SDK, which is under the
// WalletConnect Community License and is not open source. It uses only Apple's system frameworks (Foundation,
// CryptoKit, Security, Combine), so it has no package dependencies. See docs/walletconnect-protocol.md.
let package = Package(
    name: "FearlessWalletConnect",
    platforms: [
        .iOS(.v14),
        .macOS(.v12)
    ],
    products: [
        .library(name: "FearlessWalletConnect", targets: ["FearlessWalletConnect"])
    ],
    targets: [
        .target(
            name: "FearlessWalletConnect",
            path: "Sources/FearlessWalletConnect"
        ),
        .testTarget(
            name: "FearlessWalletConnectTests",
            dependencies: ["FearlessWalletConnect"],
            path: "Tests/FearlessWalletConnectTests"
        )
    ]
)
