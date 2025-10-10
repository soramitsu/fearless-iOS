// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FearlessUtilsCompat",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(name: "FearlessUtils", targets: ["FearlessUtils"])
    ],
    dependencies: [
        // Depend on the same shared-features-spm repo used by the app, pinned to the known-good revision
        .package(url: "https://github.com/soramitsu/shared-features-spm.git", revision: "6d6cb16b7f1f12028fe93d50a4e928a938af141e")
    ],
    targets: [
        .target(
            name: "FearlessUtils",
            dependencies: [
                .product(name: "SSFUtils", package: "shared-features-spm"),
                .product(name: "SSFStorageQueryKit", package: "shared-features-spm"),
                .product(name: "SSFRuntimeCodingService", package: "shared-features-spm"),
                .product(name: "SSFChainRegistry", package: "shared-features-spm"),
                .product(name: "SSFChainConnection", package: "shared-features-spm"),
                .product(name: "SSFExtrinsicKit", package: "shared-features-spm"),
                .product(name: "SSFHelpers", package: "shared-features-spm"),
                .product(name: "SSFModels", package: "shared-features-spm"),
                .product(name: "SSFNetwork", package: "shared-features-spm"),
                .product(name: "SSFSingleValueCache", package: "shared-features-spm"),
                .product(name: "SSFQRService", package: "shared-features-spm")
            ],
            path: "Sources/FearlessUtils"
        )
    ]
)
