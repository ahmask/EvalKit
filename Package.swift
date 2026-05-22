// swift-tools-version: 6.0
// EvalKit — all processing is on-device. No data leaves the device.
//
// Platform compatibility per target:
//
//   EvalKit               — core types (EvaluationReport, EvaluationMetrics, EvaluationResult,
//                           TextEvaluationCase, P90Calculator). Pure Foundation. iOS 16+, macOS 13+.
//   EvalKitClassification — Classification reporters (StandardClassificationReporter,
//                           MultiLabelClassificationReporter). iOS 16+, macOS 13+.
//   EvalKitJudge          — LLM-as-a-Judge evaluation (LLMJudgeReporter, LLMJudgeRunner,
//                           JudgeDimension, JudgeReport, JudgeMetrics). Does NOT import
//                           FoundationModels — the caller provides the judge LLM closure.
//                           iOS 16+. Requires iOS 26+ judge closure for FM-based judging.
//   EvalKitRules          — Deterministic output quality rules (MaxWordsRule, MaxSentencesRule,
//                           RegexRule, AllowedItemsRule, LanguageMatchRule, ValidJSONRule,
//                           RulesReporter). iOS 16+, macOS 13+.
//   EvalKitRetrieval      — Retrieval evaluation utilities. iOS 16+, macOS 13+.
//
// SPM does not support per-target platform declarations — the package minimum covers all targets.

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
    ]
)
