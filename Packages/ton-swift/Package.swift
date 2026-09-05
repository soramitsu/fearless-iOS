// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "TonSwift",
    platforms: [
        .iOS(.v13),
        .macOS(.v12)
    ],
    products: [
        .library(name: "TonSwift", targets: ["TonSwift"]),
    ],
    dependencies: [
        .package(url: "https://github.com/attaswift/BigInt", .exact("5.3.0")),
        .package(url: "https://github.com/bitmark-inc/tweetnacl-swiftwrap", .upToNextMajor(from: "1.0.0"))
    ],
    targets: [
        .target(
            name: "TonSwift",
            dependencies: [
                .product(name: "BigInt", package: "BigInt"),
                .product(name: "TweetNacl", package: "tweetnacl-swiftwrap"),
            ]),
        .testTarget(
            name: "TonSwiftTests",
            dependencies: [
                .byName(name: "TonSwift"),
                .product(name: "BigInt", package: "BigInt"),
                .product(name: "TweetNacl", package: "tweetnacl-swiftwrap"),
            ]),
    ]
)
