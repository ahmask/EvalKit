# EvalKit

> On-device evaluation framework for Core ML and Apple Foundation Models.  
> All computation runs on-device. No data leaves the device.

[![Test EvalKit Package](https://github.com/ahmask/EvalKit/actions/workflows/test-package.yml/badge.svg)](https://github.com/ahmask/EvalKit/actions/workflows/test-package.yml)
[![Swift 6](https://img.shields.io/badge/Swift-6-orange)](https://swift.org)
[![iOS 18+](https://img.shields.io/badge/iOS-18%2B-blue)](https://developer.apple.com/ios/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green)](LICENSE)

---

## What is EvalKit?

EvalKit is a Swift Package that provides the evaluation backbone for on-device AI features. It defines the protocols, data models, and metric calculators that are shared across apps that evaluate Core ML models and Apple Intelligence Foundation Models.

Instead of reimplementing accuracy, precision/recall/F1, latency measurement, and result aggregation in each app, EvalKit provides a single, tested implementation that every on-device AI project can import.

**What it is:**
- Protocol scaffold for writing evaluation runners and reporters
- Metric calculators: accuracy, P/R/F1, latency (P90, mean, std), false-positive/negative rates
- Ready-made runners for CoreML and Foundation Models
- Zero ML framework imports in the core target — it works in any iOS/macOS project

**What it is not:**
- A model training tool
- A cloud evaluation service
- A replacement for Xcode's model validation workflow

---

## Architecture

EvalKit ships three targets. Import only what you need:

```
EvalKit (core)
├── Protocols:  EvaluationCase, EvaluationRunner, EvaluationReporter
├── Models:     EvaluationResult, EvaluationMetrics, EvaluationReport
└── Metrics:    PrecisionRecallF1, LatencyMeasurer, P90Calculator, FalseRateCalculator

EvalKitCoreML              → depends on EvalKit + CoreML
├── CoreMLTextCase
└── CoreMLLatencyRunner

EvalKitFoundation          → depends on EvalKit only (no FoundationModels import)
├── FoundationModelCase
└── FoundationModelRunner
```

| Target | Use when |
|---|---|
| `EvalKit` | Core protocols and metrics only. No ML imports. Works in any project. |
| `EvalKitCoreML` | Your feature uses a `.mlmodel` / `.mlpackage` for classification. |
| `EvalKitFoundation` | Your feature uses `LanguageModelSession` (Apple Foundation Models). |

---

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
.package(url: "https://github.com/ahmask/EvalKit", from: "1.0.0")
```

Then add the target you need to your app or library target:

```swift
.target(
    name: "MyApp",
    dependencies: [
        .product(name: "EvalKit",            package: "EvalKit"),
        .product(name: "EvalKitCoreML",       package: "EvalKit"),  // optional
        .product(name: "EvalKitFoundation",   package: "EvalKit"),  // optional
    ]
)
```

### Xcode

**File › Add Package Dependencies…** → paste `https://github.com/ahmask/EvalKit`

For local development:

```swift
.package(path: "../EvalKit")
```

---

## Concepts

The evaluation flow has three roles:

```
EvaluationCase  ──►  EvaluationRunner  ──►  [EvaluationResult]  ──►  EvaluationReporter  ──►  EvaluationReport
   input/label        run one case            raw per-case outcome      aggregate metrics          final report
```

1. **`EvaluationCase`** — describes one test case: an `id`, `input`, and `expectedOutput`.
2. **`EvaluationRunner`** — calls your model for one case and returns an `EvaluationResult` (always — errors are captured into `result.error` rather than thrown).
3. **`EvaluationReporter`** — aggregates a batch of `EvaluationResult` values into an `EvaluationReport` with computed `EvaluationMetrics` and a baseline pass/fail verdict.

---

## Usage

### 1 — Core ML classification

```swift
import EvalKit
import EvalKitCoreML

// Define test cases from your labeled dataset
let cases = dataset.map {
    CoreMLTextCase(id: "\($0.id)", input: $0.text, expectedOutput: $0.label)
}

// Create a runner with your CoreML model's classify closure
let runner = CoreMLLatencyRunner { text in
    try myNLModel.predictedLabel(for: text) ?? ""
}

// Run all cases
var results: [EvaluationResult] = []
for testCase in cases {
    let result = try await runner.run(testCase)
    results.append(result)
}

// Compute metrics
let labels = MyLabel.allCases.map(\.rawValue)
let metrics = PrecisionRecallF1.compute(from: results, labels: labels)

print("Accuracy: \(metrics.accuracy)")
print("Macro F1: \(metrics.macroF1)")
```

### 2 — Foundation Models (Apple Intelligence)

```swift
import Foundation
import FoundationModels
import EvalKit
import EvalKitFoundation

// Availability guard — always use the enum pattern, not isAvailable (Bool)
guard case .available = SystemLanguageModel.default.availability else { return }

let instructions = "Classify the input as positive or negative. Reply with one word only."

let runner = FoundationModelRunner { input in
    let session = LanguageModelSession(instructions: instructions)
    let response = try await session.respond(to: input)
    let label = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
    return .init(predicted: label)
}

let cases = dataset.map {
    FoundationModelCase(id: $0.id, input: $0.text, expectedOutput: $0.expectedLabel)
}

var results: [EvaluationResult] = []
for testCase in cases {
    let result = try await runner.run(testCase)
    results.append(result)
}

let metrics = PrecisionRecallF1.compute(from: results, labels: ["positive", "negative"])
```

### 3 — Latency measurement

`LatencyMeasurer` provides thread-safe, monotonic wall-clock timing:

```swift
import EvalKit

// Returns (result, latencyMs) — rethrows on error, latency is 0 on error
let (response, latencyMs) = await LatencyMeasurer.measure {
    try await session.respond(to: prompt)
}

// Always records elapsed time, even when the operation throws
var latencyMs: Double = 0
do {
    let response = try await LatencyMeasurer.measureCapturingErrors(into: &latencyMs) {
        try await session.respond(to: prompt)
    }
} catch {
    print("Error after \(latencyMs) ms: \(error)")
}
```

### 4 — P90 and descriptive statistics

```swift
import EvalKit

let latencies = results.map(\.latencyMs)

let mean = P90Calculator.mean(latencies)           // arithmetic mean
let p90  = P90Calculator.p90(latencies)            // 90th percentile
let std  = P90Calculator.standardDeviation(latencies)
```

### 5 — Use `StandardClassificationReporter` (new in 1.1.0)

For multi-class text classification, skip writing your own reporter:

```swift
import EvalKit

let labels = MyCategory.allCases.map(\.rawValue)
let reporter = StandardClassificationReporter(labels: labels, minimumAccuracy: 0.85)
let report = reporter.report(from: results, featureName: "MyFeature")

print(report.passedBaseline)           // true / false
print(report.metrics.accuracy ?? 0)   // e.g. 0.847
print(report.metrics.macroF1 ?? 0)    // e.g. 0.844
```

For features that need hallucination tracking, custom baselines, or extended metrics,
write a feature-specific `EvaluationReporter` that calls `PrecisionRecallF1.compute()` directly.

### 6 — Read the confusion matrix

```swift
import EvalKit

let prf = PrecisionRecallF1.compute(from: results, labels: labels)
let cm = prf.confusionMatrix

// Count misclassifications between two specific labels
let misclassified = cm.count(expected: "baggage", predicted: "checkin")

// Iterate the full matrix
for (rowIdx, label) in cm.labels.enumerated() {
    let row = cm.matrix[rowIdx]
    print("\(label): \(row)")
}
```

### 7 — Implement a custom EvaluationReporter

```swift
import EvalKit

struct MyReporter: EvaluationReporter {
    let minAccuracy: Double = 0.85

    func report(from results: [EvaluationResult], featureName: String) -> EvaluationReport {
        let labels  = MyLabel.allCases.map(\.rawValue)
        let prf     = PrecisionRecallF1.compute(from: results, labels: labels)
        let lats    = results.map(\.latencyMs)

        let metrics = EvaluationMetrics(
            totalCases:        results.count,
            passRate:          prf.accuracy,
            errorCount:        results.filter { $0.error != nil }.count,
            accuracy:          prf.accuracy,
            macroPrecision:    prf.macroPrecision,
            macroRecall:       prf.macroRecall,
            macroF1:           prf.macroF1,
            weightedPrecision: prf.weightedPrecision,
            weightedRecall:    prf.weightedRecall,
            weightedF1:        prf.weightedF1,
            latencyMsMean:     P90Calculator.mean(lats),
            latencyMsP90:      P90Calculator.p90(lats)
        )

        return EvaluationReport(
            featureName:         featureName,
            metrics:             metrics,
            results:             results,
            passedBaseline:      prf.accuracy >= minAccuracy,
            baselineDescription: "accuracy >= \(minAccuracy)"
        )
    }
}
```

---

## Example: FeedbackClassification

The `OnDeviceAIExamples/FeedbackClassification` example app demonstrates how EvalKit is used in a real iOS project:

```
FeedbackClassification/
└── Evaluation/
    ├── FeedbackClassificationCase.swift          → EvaluationCase wrapping LabeledExample
    ├── FeedbackClassificationEvaluationRunner.swift → CoreML runner (CoreMLLatencyRunner)
    ├── FeedbackClassificationLLMRunner.swift     → Foundation Models runner (EvaluationRunner)
    └── FeedbackClassificationReporter.swift      → EvaluationReporter, baseline = 85%
```

The app's `LLMEvaluator` (SwiftUI boundary layer) uses:
- **`FeedbackClassificationLLMRunner`** to run each of 72 labeled queries through the on-device model
- **`PrecisionRecallF1.compute()`** to calculate accuracy, macro/weighted P/R/F1
- **`P90Calculator.mean()`** for average latency

This produces metrics consistent with the CMLVSLLM reference app (83.3% accuracy, ~935 ms avg latency).

---

## Privacy

> **All evaluation runs entirely on-device. No user input, model output, or evaluation data is ever sent to a network endpoint or written outside the test bundle.**

The privacy comment `// EvalKit — all processing is on-device. No data leaves the device.` appears at the top of every public file as a reminder.

---

## CI

The `test-package.yml` workflow runs `swift test` on every push and pull request to `main`.

[![Test EvalKit Package](https://github.com/ahmask/EvalKit/actions/workflows/test-package.yml/badge.svg)](https://github.com/ahmask/EvalKit/actions/workflows/test-package.yml)

---

## License

MIT — see [LICENSE](LICENSE).
