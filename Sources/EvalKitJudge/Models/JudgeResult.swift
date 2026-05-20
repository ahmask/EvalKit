// EvalKit — all processing is on-device. No data leaves the device.
//
// JudgeResult.swift
// EvalKitJudge/Models
//
// The complete judge evaluation for a single test case across all configured dimensions.

import Foundation

/// The complete judge evaluation for a single test case across all configured dimensions.
///
/// ## Purpose
///
/// `JudgeResult` is the per-case output of `LLMJudgeRunner`. It collects the
/// `JudgeScore` for every evaluated dimension, the total latency across all dimension
/// calls for this case, and any error that prevented evaluation.
///
/// `JudgeReport.results` contains one `JudgeResult` per test case in the batch.
///
/// ## When to use
///
/// Inspect `JudgeResult` values from `JudgeReport.results` to diagnose which specific
/// cases failed which dimensions. Use `score(for:)` to look up a specific dimension,
/// or iterate `scores` to see all dimensions for a case.
public struct JudgeResult: Sendable {

    // MARK: - Properties

    /// Stable identifier matching the originating `EvaluationCase.id`.
    ///
    /// Use this to correlate a failed result back to its source test case for debugging.
    public let caseId: String

    /// The judge's scores for each configured dimension.
    ///
    /// Contains one `JudgeScore` per dimension that was evaluated for this case.
    /// A case where the `outputProvider` threw will have an empty `scores` array
    /// and a non-nil `error`.
    public let scores: [JudgeScore]

    /// Total judge evaluation latency for this case in milliseconds.
    ///
    /// Includes the time for `outputProvider` to generate the model output PLUS
    /// the sum of all `LLMJudgeRunner.evaluate` calls (one per dimension, sequential).
    /// High latency here may indicate slow judge LLM responses.
    public let latencyMs: Double

    /// Non-nil if an error occurred during evaluation of this case.
    ///
    /// Set when `outputProvider` throws or when all judge LLM calls fail to return
    /// parseable responses. A non-nil `error` implies `allPassed == false` and
    /// `scores` may be empty. The batch continues to evaluate other cases.
    public let error: String?

    // MARK: - Computed

    /// `true` if every dimension's score meets or exceeds its passing threshold.
    ///
    /// Returns `false` when `scores` is empty (e.g. the case errored out).
    /// A case passes only if ALL evaluated dimensions pass — a single failing
    /// dimension causes `allPassed == false`.
    public var allPassed: Bool {
        guard !scores.isEmpty else { return false }
        return scores.allSatisfy(\.passed)
    }

    /// Arithmetic mean of all dimension scores across all evaluated dimensions. In `[0.0, 1.0]`.
    ///
    /// Returns `0.0` if `scores` is empty. A rough summary signal across all dimensions —
    /// use `scores` directly when you need dimension-specific values.
    public var averageScore: Double {
        guard !scores.isEmpty else { return 0 }
        return scores.map(\.score).reduce(0, +) / Double(scores.count)
    }

    // MARK: - Methods

    /// Returns the score for the named dimension, or `nil` if it was not evaluated.
    ///
    /// Returns `nil` when the dimension was not part of the configured evaluation set,
    /// or when the case errored out before that dimension could be scored.
    ///
    /// - Parameter dimension: The dimension name (e.g. `"fluency"`, `"recall"`).
    /// - Returns: The `JudgeScore` for that dimension, or `nil` if not evaluated.
    public func score(for dimension: String) -> JudgeScore? {
        scores.first { $0.dimension == dimension }
    }

    // MARK: - Init

    /// Create a judge result.
    ///
    /// - Parameters:
    ///   - caseId: Stable test-case identifier matching `EvaluationCase.id`.
    ///   - scores: Per-dimension `JudgeScore` values from `LLMJudgeRunner`.
    ///   - latencyMs: Total judge evaluation latency for this case in milliseconds.
    ///   - error: Human-readable error message if evaluation failed. Defaults to `nil`.
    public init(caseId: String, scores: [JudgeScore], latencyMs: Double, error: String? = nil) {
        self.caseId = caseId
        self.scores = scores
        self.latencyMs = latencyMs
        self.error = error
    }
}
