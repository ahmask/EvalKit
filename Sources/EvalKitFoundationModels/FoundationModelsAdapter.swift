// EvalKit — all processing is on-device. No data leaves the device.
//
// FoundationModelsAdapter.swift
// EvalKitFoundationModels
//
// Wraps a LanguageModelSession call into the closure shape expected by LLMJudgeRunner.

import Foundation
import FoundationModels

/// Adapts Apple's `LanguageModelSession` into the `@Sendable (String) async throws -> String`
/// closure shape that `LLMJudgeRunner` expects.
///
/// ## What is this?
///
/// `FoundationModelsAdapter` is the bridge between EvalKit's judge infrastructure and
/// Apple's FoundationModels framework. It handles availability checking, session creation,
/// and response extraction for each judge prompt call. Each call creates a fresh
/// `LanguageModelSession` — this is intentional, since judge prompts are independent
/// queries and a fresh session prevents context contamination between dimension evaluations.
///
/// ## When to use it
///
/// You do not need to use `FoundationModelsAdapter` directly in normal usage.
/// It is created and managed internally by `FoundationModelsJudgeReporter`.
///
/// Use it directly only if you are building a custom integration that needs the
/// `@Sendable (String) async throws -> String` closure shape wired to Apple Intelligence,
/// without using `FoundationModelsJudgeReporter` as the orchestrator.
///
/// ## When NOT to use it
///
/// - **Simulator or macOS without Apple Intelligence**: `respond(to:)` throws
///   `EvalKitFoundationModelsError.modelNotAvailable`. Use `LLMJudgeReporter` with a
///   mock closure instead.
/// - **Custom or fine-tuned models**: Use `LLMJudgeReporter` with your own judge closure.
/// - **Unit tests**: Use `LLMJudgeRunner` directly with a deterministic mock closure.
///
/// ## Requirements
///
/// Requires iOS 26.0+ or macOS 26.0+ with Apple Intelligence enabled.
/// `respond(to:)` checks `SystemLanguageModel.default.availability` before each call
/// and throws `EvalKitFoundationModelsError.modelNotAvailable` if the model is not
/// available on this device.
@available(iOS 26.0, macOS 26.0, *)
public struct FoundationModelsAdapter: Sendable {

    // MARK: - Properties

    private let judgeInstructions: String?

    // MARK: - Init

    /// Create an adapter for the on-device judge session.
    ///
    /// - Parameter judgeInstructions: Optional system instructions passed to each
    ///   `LanguageModelSession` created per prompt call. Use to specialise the judge's
    ///   evaluation stance — for example:
    ///   `"You are an expert evaluator for airline customer communications."`
    ///   When `nil`, sessions use no system instructions.
    public init(judgeInstructions: String? = nil) {
        self.judgeInstructions = judgeInstructions
    }

    // MARK: - Responding

    /// Send a judge prompt to the on-device model and return its raw text response.
    ///
    /// Creates a new `LanguageModelSession` per call so each dimension evaluation starts
    /// with a clean context. Checks `SystemLanguageModel.default.availability` first and
    /// throws if Apple Intelligence is not available.
    ///
    /// - Parameter prompt: The fully resolved judge prompt string, produced by
    ///   `JudgeDimension.buildPrompt(input:output:language:)` with all placeholders
    ///   substituted. The response is expected to be a raw JSON object matching the
    ///   dimension's scoring pattern.
    /// - Returns: The model's raw response string (a JSON object).
    /// - Throws: `EvalKitFoundationModelsError.modelNotAvailable` when
    ///   `SystemLanguageModel.default.availability != .available`.
    public func respond(to prompt: String) async throws -> String {
        guard SystemLanguageModel.default.availability == .available else {
            throw EvalKitFoundationModelsError.modelNotAvailable
        }
        let session: LanguageModelSession
        if let instructions = judgeInstructions {
            session = LanguageModelSession(instructions: instructions)
        } else {
            session = LanguageModelSession()
        }
        let response = try await session.respond(to: prompt)
        return response.content
    }
}

// MARK: - Errors

/// Errors thrown by `EvalKitFoundationModels` types.
public enum EvalKitFoundationModelsError: Error, Sendable {

    /// Apple Intelligence is not available on this device or has not been enabled.
    ///
    /// Thrown by `FoundationModelsAdapter.respond(to:)` when
    /// `SystemLanguageModel.default.availability != .available`.
    ///
    /// **Common causes:**
    /// - Running on iOS Simulator (Apple Intelligence is not supported on simulator)
    /// - Running on a device that is not eligible for Apple Intelligence
    /// - Apple Intelligence has not been enabled in Settings on an eligible device
    /// - Running on macOS without Apple Intelligence support enabled
    ///
    /// **How to resolve for testing:**
    /// Use `LLMJudgeReporter` with a custom judge closure for simulator and macOS testing:
    /// ```swift
    /// let reporter = LLMJudgeReporter(
    ///     dimensions: [.fluency(), .tone()],
    ///     minimumPassRate: 0.80
    /// ) { prompt in
    ///     // Return deterministic mock JSON
    ///     return #"{"passed": true, "reasoning": "Mock: always passes"}"#
    /// }
    /// ```
    case modelNotAvailable
}

extension EvalKitFoundationModelsError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .modelNotAvailable:
            return """
            Apple Intelligence is not available on this device or has not been enabled. \
            EvalKitFoundationModels requires iOS 26.0+ or macOS 26.0+ with Apple Intelligence \
            enabled. Use LLMJudgeReporter with a custom judge closure for testing on simulator.
            """
        }
    }
}
