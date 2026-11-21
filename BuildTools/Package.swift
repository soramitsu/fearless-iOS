// swift-tools-version:5.9
import PackageDescription

// All targets use the source snapshots recorded in sources.json.
let package = Package(
    name: "FearlessBuildTools",
    platforms: [.macOS(.v10_15)],
    products: [
        .executable(name: "rswift", targets: ["rswift"]),
        .executable(name: "swiftformat", targets: ["CommandLineTool"])
    ],
    targets: [
        .target(name: "Commander", path: "Vendor/Commander/Sources/Commander"),
        .target(name: "XcodeEdit", path: "Vendor/XcodeEdit/Sources/XcodeEdit"),
        .target(name: "RswiftCore", dependencies: ["Commander", "XcodeEdit"], path: "Vendor/rswift/Sources/RswiftCore"),
        .executableTarget(name: "rswift", dependencies: ["RswiftCore"], path: "Vendor/rswift/Sources/rswift"),
        .target(name: "SwiftFormat", path: "Vendor/swiftformat/Sources", exclude: ["Info.plist", "SwiftFormat.h"]),
        .executableTarget(name: "CommandLineTool", dependencies: ["SwiftFormat"], path: "Vendor/swiftformat/CommandLineTool")
    ]
)
