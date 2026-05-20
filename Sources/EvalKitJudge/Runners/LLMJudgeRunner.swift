// EvalKit — all processing is on-device. No data leaves the device.
//
// LLMJudgeRunner.swift
// EvalKitJudge/Runners
//
// A concrete JudgeRunner that evaluates generated text using a judge LLM closure.

import Foundation

/// A concrete `JudgeRunner` that evaluates generated text using a judge LLM closure.
///
/// ## Purpose
///
/// `LLMJudgeRunner` is the evaluation engine for LLM-as-a-Judge workflows. For each
/// test case, it calls the judge LLM once per configured dimension (sequentially within
/// a case), parses the structured JSON response, and produces a `JudgeResult` with
/// scores for every dimension.
///
/// It handles all three scoring patterns defined by `JudgeScoringPattern`:
/// - **Binary** — expects `{"passed": true|false, "reasoning": "..."}`. Score = 1.0/0.0.
/// - **Holistic** — expects `{"score": <1-5>, "reasoning": "..."}`.
/// - **Item-by-item** — expects `{"results": [{"fact": "...", "score": 0|1, "reasoning": "..."}]}`.
///   Final score = fraction of facts with score `1`.
///
/// ## When to use
///
/// Use `LLMJudgeRunner` via `LLMJudgeReporter` for any feature where output quality
/// cannot be checked deterministically — tone, fluency, coherence, groundedness, safety.
/// Provide the `judge` closure to route prompts to your on-device judge LLM.
///
/// ## When not to use
///
/// - **Deterministic checks** (word count, JSON validity, vocabulary): Use `EvaluationRule`
///   conformers in EvalKitRules. Rules are faster, cheaper, and more reliable for things
///   that can be verified with code.
/// - **Classification accuracy** (predicted label vs expected label): Use EvalKitClassification.
///
/// ## Usage example
///
/// ```swift
/// let runner = LLMJudgeRunner(
///     dimensions: [.fluency(language: "de"), .tone(), .safety()],
///     passingThreshold: 3.0,
///     language: "de"
/// ) { prompt in
///     try await judgeSession.respond(to: prompt).content
/// }
/// ```
public struct LLMJudgeRunner: JudgeRunner, Sendable {

    // MARK: - Types

    public typealias Score = JudgeResult

    // MARK: - Properties

    private let dimensions: [JudgeDimension]
    private let passingThreshold: Double
    private let itemByItemPassingThreshold: Double
    private let language: String?
    private let judge: @Sendable (String) async throws -> String

    // MARK: - Init

    /// Create an LLM judge runner.
    ///
    /// - Parameters:
    ///   - dimensions: The quality dimensions to evaluate. Each dimension adds one judge
    ///     LLM call per test case. Keep this list focused — more dimensions means more
    ///     latency per case.
    ///   - passingThreshold: Raw score `[1.0, 5.0]` at or above which holistic dimensions
    ///     are considered passing. Default `3.0` (acceptable quality). Set higher (e.g. `4.0`)
    ///     for customer-facing features with strict quality requirements.
    ///   - itemByItemPassingThreshold: Ratio `[0.0, 1.0]` at or above which item-by-item
    ///     dimensions are considered passing. Default `0.75` (75% of facts found). Set higher
    ///     for recall-critical features.
    ///   - language: Optional BCP-47 language tag (e.g. `"de"`) injected into the fluency
    ///     dimension's prompt. Pass the user's language when evaluating multilingual features.
    ///     Ignored by non-fluency dimensions.
    ///   - judge: Closure that sends a prompt string to the judge LLM and returns its raw
    ///     text response. Must return valid JSON in the format expected by the dimension's
    ///     scoring pattern. Errors from this closure are caught and stored in `JudgeResult.error`.
    public init(
        dimensions: [JudgeDimension],
        passingThreshold: Double = 3.0,
        itemByItemPassingThreshold: Double = 0.75,
        language: String? = nil,
        judge: @escaping @Sendable (String) async throws -> String
    ) {
        self.dimensions = dimensions
        self.passingThreshold = passingThreshold
        self.itemByItemPassingThreshold = itemByItemPassingThreshold
        self.language = language
        self.judge = judge
    }

    // MARK: - JudgeRunner

    /// Evaluate a test case across all configured dimensions using their default key facts.
    ///
    /// Calls the judge LLM once per dimension, sequentially. For item-by-item dimensions,
    /// uses the key facts embedded in the dimension's `scoringPattern`. Never throws — all
    /// errors from `judge` are captured in the returned `JudgeResult.error`.
    ///
    /// - Parameters:
    ///   - caseId: Stable test-case identifier for the returned `JudgeResult`.
    ///   - input: The original input given to the model under evaluation.
    ///   - output: The generated response from the model under evaluation.
    /// - Returns: A `JudgeResult` with scores for all dimensions and total latency.
    public func evaluate(caseId: String, input: String, output: String) async -> JudgeResult {
        await evaluate(caseId: caseId, input: input, output: output, keyFactsOverride: [:])
    }

    /// Evaluate a test case with per-dimension key-facts overrides.
    ///
    /// For item-by-item dimensions (e.g. groundedness, recall), `keyFactsOverride` provides
    /// per-case facts instead of the dimension's default `keyFacts`. This allows each test
    /// case in your dataset to specify the exact facts the judge should verify for that case.
    ///
    /// Called automatically by `LLMJudgeReporter` with facts from `keyFactsProvider`.
    /// Dimensions not in `keyFactsOverride` use their default `keyFacts` from `scoringPattern`.
    ///
    /// - Parameters:
    ///   - caseId: Stable test-case identifier.
    ///   - input: The original input given to the model under evaluation.
    ///   - output: The generated response from the model under evaluation.
    ///   - keyFactsOverride: Maps dimension name → list of key facts to use for that
    ///     dimension instead of the dimension's default `keyFacts`. Keys that are not
    ///     present in this dictionary fall back to the dimension's default facts.
    /// - Returns: A `JudgeResult` with scores for all dimensions and total latency.
    public func evaluate(
        caseId: String,
        input: String,
        output: String,
        keyFactsOverride: [String: [String]] = [:]
    ) async -> JudgeResult {
        let start = Date()
        var scores: [JudgeScore] = []

        for dimension in dimensions {
            let judgeScore = await evaluateDimension(
                dimension,
                input: input,
                output: output,
                keyFactsOverride: keyFactsOverride
            )
            scores.append(judgeScore)
        }

        let latencyMs = Date().timeIntervalSince(start) * 1000
        return JudgeResult(caseId: caseId, scores: scores, latencyMs: latencyMs)
    }

    // MARK: - Private

    private func evaluateDimension(
        _ dimension: JudgeDimension,
        input: String,
        output: String,
        keyFactsOverride: [String: [String]]
    ) async -> JudgeScore {
        switch dimension.scoringPattern {
        case .binary:
            return await evaluateBinary(dimension, input: input, output: output)
        case .holistic:
            return await evaluateHolistic(dimension, input: input, output: output)
        case .itemByItem(let defaultFacts):
            let facts = keyFactsOverride[dimension.name] ?? defaultFacts
            let effectiveDimension: JudgeDimension
            if keyFactsOverride[dimension.name] != nil {
                effectiveDimension = JudgeDimension(
                    name: dimension.name,
                    promptTemplate: dimension.promptTemplate,
                    scoringPattern: .itemByItem(keyFacts: facts)
                )
            } else {
                effectiveDimension = dimension
            }
            return await evaluateItemByItem(effectiveDimension, facts: facts, input: input, output: output)
        }
    }

    private func evaluateBinary(
        _ dimension: JudgeDimension,
        input: String,
        output: String
    ) async -> JudgeScore {
        let binaryThreshold = 1.0
        let prompt = dimension.buildPrompt(input: input, output: output, language: language)
        let raw: String
        do {
            raw = try await judge(prompt)
        } catch {
            return JudgeScore(
                dimension: dimension.name,
                score: 0.0,
                reasoning: "Failed to parse: \(String(error.localizedDescription.prefix(200)))",
                passingThreshold: binaryThreshold
            )
        }

        guard
            let data = raw.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let passed = json["passed"] as? Bool,
            let reasoning = json["reasoning"] as? String
        else {
            let truncated = String(raw.prefix(200))
            return JudgeScore(
                dimension: dimension.name,
                score: 0.0,
                reasoning: "Failed to parse: \(truncated)",
                passingThreshold: binaryThreshold
            )
        }

        return JudgeScore(
            dimension: dimension.name,
            score: passed ? 1.0 : 0.0,
            reasoning: reasoning,
            passingThreshold: binaryThreshold
        )
    }

    private func evaluateHolistic(
        _ dimension: JudgeDimension,
        input: String,
        output: String
    ) async -> JudgeScore {
        let prompt = dimension.buildPrompt(input: input, output: output, language: language)
        let raw: String
        do {
            raw = try await judge(prompt)
        } catch {
            return JudgeScore(
                dimension: dimension.name,
                score: 1.0,
                reasoning: "Failed to parse: \(String(error.localizedDescription.prefix(200)))",
                passingThreshold: passingThreshold
            )
        }

        guard
            let data = raw.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let scoreValue = json["score"],
            let reasoning = json["reasoning"] as? String
        else {
            let truncated = String(raw.prefix(200))
            return JudgeScore(
                dimension: dimension.name,
                score: 1.0,
                reasoning: "Failed to parse: \(truncated)",
                passingThreshold: passingThreshold
            )
        }

        let scoreDouble: Double
        if let intScore = scoreValue as? Int {
            scoreDouble = Double(intScore)
        } else if let dblScore = scoreValue as? Double {
            scoreDouble = dblScore
        } else {
            let truncated = String(raw.prefix(200))
            return JudgeScore(
                dimension: dimension.name,
                score: 1.0,
                reasoning: "Failed to parse: \(truncated)",
                passingThreshold: passingThreshold
            )
        }

        return JudgeScore(
            dimension: dimension.name,
            score: scoreDouble,
            reasoning: reasoning,
            passingThreshold: passingThreshold
        )
    }

    private func evaluateItemByItem(
        _ dimension: JudgeDimension,
        facts: [String],
        input: String,
        output: String
    ) async -> JudgeScore {
        let prompt = dimension.buildPrompt(input: input, output: output, language: language)
        let raw: String
        do {
            raw = try await judge(prompt)
        } catch {
            return JudgeScore(
                dimension: dimension.name,
                score: 0.0,
                reasoning: "Failed to parse: \(String(error.localizedDescription.prefix(200)))",
                passingThreshold: itemByItemPassingThreshold,
                factScores: []
            )
        }

        guard
            let data = raw.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let results = json["results"] as? [[String: Any]]
        else {
            let truncated = String(raw.prefix(200))
            return JudgeScore(
                dimension: dimension.name,
                score: 0.0,
                reasoning: "Failed to parse: \(truncated)",
                passingThreshold: itemByItemPassingThreshold,
                factScores: []
            )
        }

        var factScores: [JudgeScore.FactScore] = []
        for item in results {
            let fact      = item["fact"]      as? String ?? ""
            let score     = item["score"]     as? Int    ?? 0
            let reasoning = item["reasoning"] as? String ?? ""
            factScores.append(JudgeScore.FactScore(fact: fact, score: score, reasoning: reasoning))
        }

        let total = factScores.count
        let sum   = factScores.map(\.score).reduce(0, +)
        let ratio = total > 0 ? Double(sum) / Double(total) : 0.0
        let reasoningSummary = "\(sum)/\(total) facts found"

        return JudgeScore(
            dimension: dimension.name,
            score: ratio,
            reasoning: reasoningSummary,
            passingThreshold: itemByItemPassingThreshold,
            factScores: factScores
        )
    }
}
