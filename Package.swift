// swift-tools-version: 6.0
// EvalKit — all processing is on-device. No data leaves the device.
//
// Platform compatibility per target:
//
//   EvalKit          — pure Foundation. iOS 16+, macOS 13+.
//   EvalKitCoreML    — CoreML (available since iOS 11). iOS 16+, macOS 13+.
//   EvalKitFoundation — generic async-closure wrapper. Does NOT import FoundationModels.
//                       iOS 26+ gating is the caller's responsibility via @available(iOS 26, *).
//                       The target itself compiles on iOS 16+.
//
// SPM does not support per-target platform declarations — the package minimum covers all
// targets. EvalKitFoundation is kept generic so it compiles anywhere; callers guard with
// @available before passing a FoundationModels-based closure to FoundationModelRunner.

import PackageDescription

let package = Package(
    name: "EvalKit",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
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
