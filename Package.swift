// swift-tools-version: 6.0
// EvalKit — all processing is on-device. No data leaves the device.

import PackageDescription

let package = Package(
    name: "EvalKit",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .library(name: "EvalKit", targets: ["EvalKit"]),
        .library(name: "EvalKitCoreML", targets: ["EvalKitCoreML"]),
        .library(name: "EvalKitFoundation", targets: ["EvalKitFoundation"])
    ],
    targets: [
        // Target 1 — core only, no ML imports, works in any iOS project
        .target(
            name: "EvalKit",
            path: "Sources/EvalKit"
        ),
        // Target 2 — CoreML evaluation utilities, depends on EvalKit
        .target(
            name: "EvalKitCoreML",
            dependencies: ["EvalKit"],
            path: "Sources/EvalKitCoreML"
        ),
        // Target 3 — Foundation Model evaluation utilities, depends on EvalKit
        .target(
            name: "EvalKitFoundation",
            dependencies: ["EvalKit"],
            path: "Sources/EvalKitFoundation"
        ),
        // Tests
        .testTarget(
            name: "EvalKitTests",
            dependencies: ["EvalKit"],
            path: "Tests/EvalKitTests"
        ),
        .testTarget(
            name: "EvalKitCoreMLTests",
            dependencies: ["EvalKitCoreML"],
            path: "Tests/EvalKitCoreMLTests"
        ),
        .testTarget(
            name: "EvalKitFoundationTests",
            dependencies: ["EvalKitFoundation"],
            path: "Tests/EvalKitFoundationTests"
        )
    ]
)
