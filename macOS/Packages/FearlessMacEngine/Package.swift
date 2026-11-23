// swift-tools-version: 6.0
import PackageDescription

let nativeProducts = ["IrohaCrypto", "SSFCrypto", "SSFKeyPair", "SSFSigner", "SSFUtils", "SSFModels",
                      "SSFRuntimeCodingService", "SSFExtrinsicKit", "SSFEraKit"]
let package = Package(
    name: "FearlessMacEngine",
    platforms: [.macOS(.v14)],
    products: [.library(name: "WalletEngine", targets: ["WalletEngine"])],
    dependencies: [.package(path: "../WalletCore"), .package(path: "../../../Native"),
                   .package(url: "https://github.com/attaswift/BigInt.git", exact: "5.3.0"),
                   .package(url: "https://github.com/soramitsu/web3-swift", exact: "7.7.7")],
    targets: [
        .target(
            name: "WalletEngine",
            dependencies: [.product(name: "WalletCore", package: "WalletCore"),
                           .product(name: "Web3", package: "web3-swift"),
                           .product(name: "BigInt", package: "BigInt")]
                + nativeProducts.map { .product(name: $0, package: "Native") },
            resources: [.process("Resources")]
        ),
        .testTarget(name: "WalletEngineTests", dependencies: ["WalletEngine"], resources: [.process("Fixtures")])
    ],
    swiftLanguageModes: [.v5]
)
