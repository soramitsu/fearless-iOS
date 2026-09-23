// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FearlessUtilsCompat",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(name: "FearlessUtils", targets: ["FearlessUtils"])
    ],
    dependencies: [
        // Depend on the same shared-features-spm repo used by the app, pinned to the Ton-ready revision
        .package(url: "https://github.com/soramitsu/shared-features-spm.git", revision: "4323032511ee788b178aa3f9ed05e2518ee21c74")
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
