// swift-tools-version: 5.9
// EvalKit — all processing is on-device. No data leaves the device.
//
// v3.0.0 — targets reorganised by evaluation problem, not by Apple framework.
//
//   EvalKit                — core protocols, shared models, shared metric helpers
//   EvalKitClassification  — primitive 1: fixed label comparison
//   EvalKitRetrieval       — primitive 2: reference set and ranked output comparison
//   EvalKitRules           — primitive 3: deterministic rule-based validation
//   EvalKitJudge           — primitive 4: LLM as judge

import PackageDescription

let package = Package(
    name: "EvalKit",
    platforms: [.iOS(.v16), .macOS(.v12)],
    products: [
        .library(name: "EvalKit",               targets: ["EvalKit"]),
        .library(name: "EvalKitClassification", targets: ["EvalKitClassification"]),
        .library(name: "EvalKitRetrieval",      targets: ["EvalKitRetrieval"]),
        .library(name: "EvalKitRules",          targets: ["EvalKitRules"]),
        .library(name: "EvalKitJudge",          targets: ["EvalKitJudge"]),
    ],
    targets: [
        .target(name: "EvalKit",               dependencies: []),
        .target(name: "EvalKitClassification", dependencies: ["EvalKit"]),
        .target(name: "EvalKitRetrieval",      dependencies: ["EvalKit"]),
        .target(name: "EvalKitRules",          dependencies: ["EvalKit"]),
        .target(name: "EvalKitJudge",          dependencies: ["EvalKit"]),
        .testTarget(name: "EvalKitTests",               dependencies: ["EvalKit"]),
        .testTarget(name: "EvalKitClassificationTests", dependencies: ["EvalKitClassification"]),
        .testTarget(name: "EvalKitRetrievalTests",      dependencies: ["EvalKitRetrieval"]),
        .testTarget(name: "EvalKitRulesTests",          dependencies: ["EvalKitRules"]),
        .testTarget(name: "EvalKitJudgeTests",          dependencies: ["EvalKitJudge"]),
    ]
)
