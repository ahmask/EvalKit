    # CLAUDE.md

    This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

    ## Commands

    ```bash
    # Build
    swift build

    # Run all tests
    swift test

    # Run a single test target
    swift test --filter EvalKitClassificationTests
    swift test --filter EvalKitJudgeTests
    swift test --filter EvalKitRetrievalTests
    swift test --filter EvalKitRulesTests
    swift test --filter EvalKitTests

    # Run a specific test method
    swift test --filter EvalKitTests/MetricsTests/test_p90_sorted
    ```

    ## Architecture

    EvalKit is a Swift Package (iOS 16+, macOS 12+) for on-device LLM evaluation. **No data leaves the device.** All five targets are independent libraries; consumers import only what they need.

    ```
    EvalKit (core)
    ├── Protocols:  EvaluationCase, EvaluationRunner, EvaluationReporter
    ├── Models:     EvaluationResult, EvaluationMetrics, EvaluationReport, TextEvaluationCase
    └── Metrics:    LatencyMeasurer, P90Calculator

    EvalKitClassification  → depends on EvalKit
    ├── Metrics:   ConfusionMatrix, PrecisionRecallF1, FalseRateCalculator
    └── Reporters: StandardClassificationReporter, MultiLabelClassificationReporter

    EvalKitRetrieval       → depends on EvalKit
    ├── Metrics:   JaccardSimilarity, BLEUScore, ROUGEScore, MeanReciprocalRank, PositionSimilarity
    ├── Runners:   SimilarityRunner
    └── Reporters: RetrievalReporter

    EvalKitRules           → depends on EvalKit
    ├── Rules:     MaxWordsRule, MaxSentencesRule, AllowedItemsRule, ValidJSONRule, RegexRule, LanguageMatchRule
    ├── Protocols: EvaluationRule
    └── Reporters: RulesReporter

    EvalKitJudge           → depends on EvalKit
    ├── Models:    JudgeDimension, JudgeScore, JudgeResult, JudgeMetrics, JudgeReport, JudgeScoringPattern
    ├── Protocols: JudgeRunner
    ├── Runners:   LLMJudgeRunner
    └── Reporters: LLMJudgeReporter
    ```

    ## Evaluation primitives — when to use which

    | Question | Answer | Use |
    |---|---|---|
    | Can you write `predicted == expected`? | Yes | `EvaluationRunner` + classification/retrieval reporter |
    | Is the output free-form text with no single correct answer? | Yes | `LLMJudgeReporter` (EvalKitJudge) |
    | Can correctness be checked mechanically (length, format, regex)? | Yes | `RulesReporter` (EvalKitRules) |

    ## Core data flow

    1. **Cases** — conform to `EvaluationCase` (or use `TextEvaluationCase` for plain strings). Each case has `id`, `input`, `expectedOutput`.
    2. **Runner** — conform to `EvaluationRunner` (or `JudgeRunner` for LLM-as-judge). Calls the model, measures latency via `LatencyMeasurer.measure(into:)`, returns `EvaluationResult`.
    3. **Reporter** — conform to `EvaluationReporter`. Aggregates `[EvaluationResult]` into `EvaluationReport` with `passedBaseline`, `metrics`, and per-case `results`.

    ## Scoring patterns (EvalKitJudge)

    - **Holistic (1–5)**: judge returns one score for the whole output. Used for fluency, tone, safety, coherence.
    - **Item-by-item (ratio)**: judge scores each key fact 0 or 1; final score = `sum / count`. Used for recall and groundedness (hallucination check).

    Built-in `JudgeDimension` presets: `.fluency()`, `.tone()`, `.safety()`, `.coherence()`, `.recall()`, `.groundedness()`. Custom dimensions via `JudgeDimension.custom(name:prompt:scoringPattern:)`.

    ## File header convention

    Every public source file begins with:
    ```swift
    // EvalKit — all processing is on-device. No data leaves the device.
    ```
    Preserve this header when adding new source files.

    ## Adding a new target

    1. Add the target to `Package.swift` with `dependencies: ["EvalKit"]`.
    2. Add a corresponding test target.
    3. Follow the `Sources/EvalKit<Name>/` directory structure with `Models/`, `Metrics/`, `Runners/`, `Reporters/`, `Protocols/` subdirectories as applicable.
