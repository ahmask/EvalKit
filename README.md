# EvalKit

> On-device evaluation framework for Core ML and Apple Foundation Models.  
> All computation runs on-device. No data leaves the device.

[![Test EvalKit Package](https://github.com/ahmask/EvalKit/actions/workflows/test-package.yml/badge.svg)](https://github.com/ahmask/EvalKit/actions/workflows/test-package.yml)
[![Swift 6](https://img.shields.io/badge/Swift-6-orange)](https://swift.org)
[![iOS 16+](https://img.shields.io/badge/iOS-16%2B-blue)](https://developer.apple.com/ios/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green)](LICENSE)

---

## Overview

EvalKit has two evaluation paths:

**Path 1 — Classification evaluation** (existing): tests whether a model picks the correct label. The answer is always right or wrong. Used with CoreML and FoundationModel classifiers.

**Path 2 — Generative evaluation / LLM as a Judge** (new): tests whether generated free-form text is good quality. Used when there is no single correct answer. A judge LLM scores the output across multiple quality dimensions using two scoring patterns:

- **Holistic (1–5)**: the judge gives one impression score. Used for fluency, tone, safety, coherence.
- **Item-by-item (0/1 per fact)**: the judge checks each key fact individually and returns a ratio. Used for recall and groundedness. For example, 3 out of 4 facts found = score 0.75.

---

## Choosing the right path

| Feature type | Recommended reporter |
|---|---|
| CoreML text classifier (fixed labels) | `CoreMLLatencyRunner` |
| CoreML tabular classifier | `CoreMLTabularRunner` |
| FoundationModel classification | `FoundationModelRunner` |
| FoundationModel free-text generation (device, iOS 26+) | `FoundationModelsJudgeReporter` |
| FoundationModel free-text generation (simulator / mock) | `LLMJudgeReporter` |
| Greeting / summary / explanation generation | `FoundationModelsJudgeReporter` |
| Any output with no single correct answer | `FoundationModelsJudgeReporter` |

> **If you can write `predicted == expected`, use `EvaluationRunner`.**  
> **If you can't — because any well-written answer is acceptable — use `JudgeRunner`.**

---

## Architecture

EvalKit ships six targets. Import only what you need:

```
EvalKit (core)
├── Protocols:  EvaluationCase, EvaluationRunner, EvaluationReporter
├── Models:     EvaluationResult, EvaluationMetrics, EvaluationReport, TextEvaluationCase
└── Metrics:    LatencyMeasurer, P90Calculator

EvalKitClassification            → depends on EvalKit
├── PrecisionRecallF1, ConfusionMatrix
├── StandardClassificationReporter
└── MultiLabelClassificationReporter

EvalKitRetrieval                 → depends on EvalKit
├── JaccardSimilarity, PositionSimilarity, BLEUScore, ROUGEScore, MeanReciprocalRank
├── SimilarityRunner
└── RetrievalReporter

EvalKitRules                     → depends on EvalKit
├── EvaluationRule, AllowedItemsRule, LanguageMatchRule
└── RulesReporter

EvalKitJudge                     → depends on EvalKit
├── JudgeDimension, JudgeMetrics, JudgeReport
├── LLMJudgeRunner
└── LLMJudgeReporter  ← escape hatch: mocking, simulator, custom models

EvalKitFoundationModels          → depends on EvalKitJudge, iOS 26+
├── FoundationModelsAdapter
└── FoundationModelsJudgeReporter  ← primary path: zero session management
```

---

## Installation

### Swift Package Manager

```swift
.package(url: "https://github.com/ahmask/EvalKit", from: "3.1.0")
```

```swift
.target(
    name: "MyApp",
    dependencies: [
        .product(name: "EvalKit",                    package: "EvalKit"),
        .product(name: "EvalKitClassification",      package: "EvalKit"),  // CoreML classification
        .product(name: "EvalKitRetrieval",           package: "EvalKit"),  // retrieval / similarity
        .product(name: "EvalKitRules",               package: "EvalKit"),  // rules-based checks
        .product(name: "EvalKitFoundationModels",    package: "EvalKit"),  // LLM judge, zero config (iOS 26+)
        // .product(name: "EvalKitJudge",            package: "EvalKit"),  // LLM judge, custom closure
    ]
)
```

| Target | Purpose | iOS |
|---|---|---|
| `EvalKit` | Core protocols and models | 16.0+ |
| `EvalKitClassification` | Accuracy, F1, confusion matrix | 16.0+ |
| `EvalKitRetrieval` | Jaccard, BLEU, MRR, ROUGE | 16.0+ |
| `EvalKitRules` | Deterministic rule validation | 16.0+ |
| `EvalKitJudge` | LLM judge (closure-based, for mocking and custom models) | 16.0+ |
| `EvalKitFoundationModels` | LLM judge (FoundationModels, zero config) | 26.0+ |

### Xcode

**File › Add Package Dependencies…** → paste `https://github.com/ahmask/EvalKit`

---

## LLM as a Judge — what each metric measures

### Fluency (binary — YES/NO)

Checks whether the generated text is grammatically correct and naturally readable.
The judge answers a factual question — is this grammatically correct? — not a subjective
impression. Binary scoring was chosen specifically for fluency to eliminate self-evaluation
bias. A broken sentence is a factual error, not a matter of opinion.

Result: `passed: true` (score = 1.0) or `passed: false` (score = 0.0).
Passing threshold: 1.0 — must pass to count.

**What it checks:**
- Grammar errors (wrong verb forms, missing articles, incorrect word order)
- Unnatural phrasing a native speaker would not use
- Incomplete or broken sentences
- Awkward repetition

**Multilingual support:** pass a BCP-47 language tag to evaluate in the correct language.
Example: `.fluency(language: "de")` evaluates German grammar in German.

**Example — passed:**
- Input: `"HON Circle member, gate 12, delayed 30 min"`
- Output: `"Welcome back, valued traveller. Your flight is delayed by 30 minutes."`
- Result: `passed: true` — correct grammar, natural phrasing.

**Example — failed:**
- Input: `"Flight LH400 cancelled"`
- Output: `"Sorry is cancelled your flight LH400."`
- Result: `passed: false` — incorrect word order, broken sentence structure.

### Groundedness (item-by-item, ratio)
Checks whether every claim in the output is grounded in the input. This is the hallucination check.  
The judge scores each key fact individually: 1 = grounded, 0 = invented or not in input.  
Final score = sum / count. Example: 2 out of 3 facts grounded = 0.67.

**Example:**
- Input: `"Senator member, boarding gate 12"`
- Output: `"Welcome! You have a lounge voucher at gate 7."` ← gate 7 and voucher not in input
- Key facts checked: `["gate is 12", "member is Senator"]` → scores: `[0, 1]` → ratio: 0.5

### Recall (item-by-item, ratio)
Checks whether the output covers all important points from the input.  
The judge scores each key fact: 1 = present or inferable, 0 = missing.  
Final score = sum / count.

**Example (claim summarisation):**
```
Key fact                                              Score
1. Claimant type is Passenger                           1
2. Route was New York to Brussels                       1
3. Promised free carry-on but charged 70 EUR            1
4. Extra charges for security check                     0  ← missing from summary
→ Recall = 3/4 = 0.75
```

### Tone (holistic, 1–5)
Checks whether the tone is polite, professional, empathetic, appropriate for airline context.  
Score 5 = excellent. Score 1 = sarcastic, rude, or dismissive.

### Safety (holistic, 1–5)
Checks for toxicity, bias (gender/racial/political), prompt injection, harmful content.  
Required for all customer-facing features.  
Score 5 = completely safe. Score 1 = harmful content present.

### Coherence (holistic, 1–5)
Checks whether the text follows logic and commonsense and fits the context.  
Score 5 = fully coherent. Score 1 = contradicts the input or makes no sense.

### Faithfulness (holistic, 1–5)
Designed for RAG (Retrieval Augmented Generation) systems. Checks whether the generated response accurately represents the retrieved context — no distortion, no misrepresentation.  
Score 5 = entirely faithful to the retrieved context. Score 1 = distorts or contradicts the source.

**Faithfulness vs Groundedness:**  
- *Groundedness* asks: "Did you invent something that was not in the input?" (hallucination check).  
- *Faithfulness* asks: "Did you represent what the source said accurately, without distorting it?" Even a real-world true fact counts as a violation if it was not in the retrieved context.  
Use both together for thorough RAG evaluation.

---

## How scores are aggregated

**Holistic dimensions:**
- `passRate` = cases with `score >= passingThreshold` / `totalCases`
- `averageScore` = mean of all scores
- `p90Score` = 90th-percentile score

**Item-by-item dimensions:**
- Per case: `score` = `sum(fact scores) / count(facts)` → a ratio between 0.0 and 1.0
- `passRate` = cases with `ratio >= itemByItemPassingThreshold` / `totalCases`
- `factPassRates` = per-fact: how often each specific fact was found across all cases (useful for identifying which information the model consistently misses)

**Overall:**
- `allPassed` per case = every dimension passed
- Overall `passRate` = cases where `allPassed` / `totalCases`
- `passedBaseline` = overall `passRate >= minimumPassRate`

---

## Code examples

### Example 1 — Classification (CoreML)

```swift
import EvalKit
import EvalKitClassification

let runner = CoreMLLatencyRunner { text in
    try myRecipeModel.prediction(text: text).label
}
let cases = dataset.map { CoreMLTextCase(id: $0.id, input: $0.text, expectedOutput: $0.label) }
var results: [EvaluationResult] = []
for c in cases { results.append(try await runner.run(c)) }

let reporter = StandardClassificationReporter(
    labels: RecipeCategory.allCases.map(\.rawValue),
    minimumAccuracy: 0.85
)
let report = reporter.report(from: results, featureName: "RecipeClassifier")
print(report.passedBaseline)
```

### Example 2 — LLM as judge: quick start (FoundationModels, iOS 26+)

Use `FoundationModelsJudgeReporter` when evaluating on a real device with Apple Intelligence.
Zero session management — the judge session is owned internally by EvalKit.

```swift
import FoundationModels
import EvalKit
import EvalKitFoundationModels

// Your existing generation session — you own this
let generationSession = LanguageModelSession(
    instructions: "You are a personalised greeting generator for an airline app."
)

// The reporter owns its own judge session — no session code needed from you
let reporter = FoundationModelsJudgeReporter(
    dimensions: [.fluency(language: "en"), .groundedness(), .tone()],
    minimumPassRate: 0.80,
    judgeInstructions: "You are an expert evaluator for airline customer communications."
)

let cases = [
    TextEvaluationCase(id: "cancel-1", input: "Flight LH400 cancelled. HON Circle member.", expectedOutput: ""),
    TextEvaluationCase(id: "gate-1",   input: "Gate changed to B22. Senator member.",       expectedOutput: ""),
]

let report = await reporter.report(
    from: cases,
    featureName: "PassengerGreeting",
    outputProvider: { testCase in
        // Call your existing feature here
        try await generationSession.respond(to: testCase.input).content
    }
)

print(report.passedBaseline)        // true / false — use as XCTest assertion or CI gate
print(report.metrics.passRate)      // e.g. 0.87
```

### Example 2a — LLM as judge: simulator or custom model (advanced)

Use `LLMJudgeReporter` when:
- Testing on simulator (use a mock closure)
- Using a custom or fine-tuned model
- Targeting iOS below 26.0
- Running on macOS

```swift
import EvalKit
import EvalKitJudge

// Simulator / unit test: return deterministic mock JSON
let reporter = LLMJudgeReporter(
    dimensions: [.fluency(), .tone()],
    minimumPassRate: 0.80
) { prompt in
    // Your session, your mock, your model
    return #"{"passed": true, "reasoning": "Mock: always passes"}"#
}
```

### Example 3 — Item-by-item evaluation (claim summarisation)

This mirrors the claim summarisation use case. The model summarises a customer complaint email and the judge checks specific facts.

```swift
import FoundationModels
import EvalKit
import EvalKitJudge

let session = LanguageModelSession()

let reporter = LLMJudgeReporter(
    dimensions: [.recall(), .groundedness()],
    minimumPassRate: 0.80,
    itemByItemPassingThreshold: 0.75  // at least 75% of facts must be present
) { prompt in
    try await session.respond(to: prompt).content
}

let cases = [
    TextEvaluationCase(id: "claim-1", input: emilyEmail, expectedOutput: ""),
    TextEvaluationCase(id: "claim-2", input: johnEmail,  expectedOutput: ""),
]

let keyFactsPerCase: [String: [String]] = [
    "claim-1": [
        "Claimant type is Passenger",
        "Route was JFK to BRU via ZRH",
        "Luggage not delivered on arrival day",
        "Luggage was damaged beyond repair",
        "Items were missing from the luggage",
        "Refund is requested"
    ],
    "claim-2": [
        "Claimant type is Passenger",
        "Charged 70 EUR for carry-on despite free email",
        "Extra charge for random security check"
    ]
]

let report = await reporter.report(
    from: cases,
    featureName: "ClaimSummarisation",
    outputProvider: { testCase in
        try await session.respond(to: "Summarise this claim: \(testCase.input)").content
    },
    keyFactsProvider: { testCase in
        let facts = keyFactsPerCase[testCase.id] ?? []
        return ["recall": facts, "groundedness": facts]
    }
)

print(report.passedBaseline)

// Per-fact breakdown — see which facts the model consistently misses
for dim in report.metrics.dimensionMetrics {
    print("\(dim.dimension) avg: \(dim.averageScore)")
    for (fact, rate) in dim.factPassRates {
        print("  '\(fact)': found \(Int(rate * 100))% of the time")
    }
}
```

### Example 4 — Custom dimension

```swift
let dim = JudgeDimension.custom(
    name: "conciseness",
    prompt: """
    Rate how concise the following response is on a scale 1–5.
    Score 5 = perfectly concise. Score 1 = unnecessarily verbose.
    Input: {input}
    Response: {output}
    You must respond with ONLY a raw JSON object:
    {"score": <1-5>, "reasoning": "<explanation>"}
    """,
    scoringPattern: .holistic
)

let reporter = LLMJudgeReporter(
    dimensions: [.fluency(), dim],
    minimumPassRate: 0.80
) { prompt in
    try await session.respond(to: prompt).content
}
```

---

## Classification metrics reference

### `StandardClassificationReporter`

```swift
let reporter = StandardClassificationReporter(labels: labels, minimumAccuracy: 0.85)
let report = reporter.report(from: results, featureName: "MyFeature")

print(report.passedBaseline)           // true / false
print(report.metrics.accuracy ?? 0)   // e.g. 0.847
print(report.metrics.macroF1 ?? 0)    // e.g. 0.844
print(report.metrics.latencyMsMean)   // e.g. 859.4 ms
```

### Latency

```swift
let latencies = results.map(\.latencyMs)
let mean = P90Calculator.mean(latencies)
let p90  = P90Calculator.p90(latencies)
```

---

## Privacy

> **All evaluation runs entirely on-device. No user input, model output, or evaluation data is ever sent to a network endpoint.**

The comment `// EvalKit — all processing is on-device. No data leaves the device.` appears at the top of every public source file as an explicit reminder.

---

## CI

[![Test EvalKit Package](https://github.com/ahmask/EvalKit/actions/workflows/test-package.yml/badge.svg)](https://github.com/ahmask/EvalKit/actions/workflows/test-package.yml)

`swift test` runs on every push and pull request to `main`.

---

## License

MIT — see [LICENSE](LICENSE).
