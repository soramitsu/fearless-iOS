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
        // This package re-exports modules from shared-features-spm that are already
        // integrated into the main app target via Xcode project settings.
        // No direct dependencies declared here; the app provides them.
    ],
    targets: [
        .target(
            name: "FearlessUtils",
            dependencies: [],
            path: "Sources/FearlessUtils"
        )
    ]
)

