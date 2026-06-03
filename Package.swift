// swift-tools-version: 6.0
// EvalKit — all processing is on-device. No data leaves the device.
//
// Platform compatibility per target:
//
//   EvalKit                    — core types (EvaluationReport, EvaluationMetrics, EvaluationResult,
//                                TextEvaluationCase, P90Calculator). Pure Foundation. iOS 16+, macOS 13+.
//   EvalKitClassification      — Classification reporters (StandardClassificationReporter,
//                                MultiLabelClassificationReporter). iOS 16+, macOS 13+.
//   EvalKitJudge               — LLM-as-a-Judge evaluation (LLMJudgeReporter, LLMJudgeRunner,
//                                JudgeDimension, JudgeReport, JudgeMetrics). Does NOT import
//                                FoundationModels — the caller provides the judge LLM closure.
//                                iOS 16+. Escape hatch for mocking, simulator, custom models.
//   EvalKitRules               — Deterministic output quality rules (MaxWordsRule, MaxSentencesRule,
//                                RegexRule, AllowedItemsRule, LanguageMatchRule, ValidJSONRule,
//                                RulesReporter). iOS 16+, macOS 13+.
//   EvalKitRetrieval           — Retrieval evaluation utilities. iOS 16+, macOS 13+.
//   EvalKitFoundationModels    — Zero-config LLM judge via Apple FoundationModels. Primary path
//                                for on-device judge evaluation. Owns the judge session internally.
//                                iOS 26+, macOS 26+. Enforced via @available checks at runtime.
//
// SPM does not support per-target platform declarations — the package minimum covers all targets.
// EvalKitFoundationModels requires Xcode 26+ / iOS 26 SDK to build.

import PackageDescription

let package = Package(
    name: "EvalKit",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(name: "EvalKit", targets: ["EvalKit"]),
        .library(name: "EvalKitClassification", targets: ["EvalKitClassification"]),
        .library(name: "EvalKitJudge", targets: ["EvalKitJudge"]),
        .library(name: "EvalKitRules", targets: ["EvalKitRules"]),
        .library(name: "EvalKitRetrieval", targets: ["EvalKitRetrieval"]),
        .library(name: "EvalKitFoundationModels", targets: ["EvalKitFoundationModels"]),
    ],
    targets: [
        // Core — no ML imports, works in any iOS 16+ project
        .target(
            name: "EvalKit",
            path: "Sources/EvalKit"
        ),
        // Classification reporters — StandardClassificationReporter, MultiLabelClassificationReporter
        .target(
            name: "EvalKitClassification",
            dependencies: ["EvalKit"],
            path: "Sources/EvalKitClassification"
        ),
        // LLM-as-a-Judge — quality evaluation via judge LLM closure (caller-provided)
        .target(
            name: "EvalKitJudge",
            dependencies: ["EvalKit"],
            path: "Sources/EvalKitJudge"
        ),
        // Deterministic rules — MaxWordsRule, RegexRule, LanguageMatchRule, etc.
        .target(
            name: "EvalKitRules",
            dependencies: ["EvalKit"],
            path: "Sources/EvalKitRules"
        ),
        // Retrieval evaluation utilities
        .target(
            name: "EvalKitRetrieval",
            dependencies: ["EvalKit"],
            path: "Sources/EvalKitRetrieval"
        ),
        // Zero-config LLM judge using Apple FoundationModels — primary judge path, iOS 26+
        // Availability enforced via @available checks. Requires Xcode 26+ / iOS 26 SDK to build.
        .target(
            name: "EvalKitFoundationModels",
            dependencies: ["EvalKitJudge"],
            path: "Sources/EvalKitFoundationModels"
        ),
        // Tests
        .testTarget(
            name: "EvalKitTests",
            dependencies: ["EvalKit"],
            path: "Tests/EvalKitTests"
        ),
        .testTarget(
            name: "EvalKitClassificationTests",
            dependencies: ["EvalKitClassification"],
            path: "Tests/EvalKitClassificationTests"
        ),
        .testTarget(
            name: "EvalKitJudgeTests",
            dependencies: ["EvalKitJudge"],
            path: "Tests/EvalKitJudgeTests"
        ),
        .testTarget(
            name: "EvalKitRulesTests",
            dependencies: ["EvalKitRules"],
            path: "Tests/EvalKitRulesTests"
        ),
        .testTarget(
            name: "EvalKitRetrievalTests",
            dependencies: ["EvalKitRetrieval"],
            path: "Tests/EvalKitRetrievalTests"
        ),
        .testTarget(
            name: "EvalKitFoundationModelsTests",
            dependencies: ["EvalKitFoundationModels"],
            path: "Tests/EvalKitFoundationModelsTests"
        ),
    ]
)
