// EvalKit — all processing is on-device. No data leaves the device.
//
// LatencyMeasurer.swift
// EvalKit/Metrics
//
// Measures wall-clock latency for async evaluation steps.

import Foundation

/// Measures wall-clock latency for async operations and returns both the result
/// and the elapsed time in milliseconds.
///
/// ## Purpose
///
/// `LatencyMeasurer` gives your `EvaluationRunner` a simple, accurate way to time
/// model calls without writing boilerplate. You wrap your model call in a `measure`
/// closure and get back both the model's result and the elapsed time — ready to
/// populate `EvaluationResult.latencyMs`.
///
/// ## When to use
///
/// Call `LatencyMeasurer` inside every `EvaluationRunner.run(_:)` implementation.
/// Every evaluation result must carry a latency value so that `EvaluationMetrics`
/// can compute `latencyMsMean` and `latencyMsP90` for UX regression tracking.
///
/// ## When not to use
///
/// `LatencyMeasurer` measures wall-clock time on the current device. Do not use it
/// for benchmarking across devices or builds — results will vary with device load,
/// thermal state, and background processes. It is intended for within-session
/// relative comparisons, not absolute performance guarantees.
///
/// ## Usage example
///
/// ```swift
/// // Overload 1 — tuple return (result + latency)
/// let (predicted, latencyMs) = try await LatencyMeasurer.measure {
///     try await myModel.predict(input)
/// }
///
/// // Overload 2 — inout binding (result only, latency stored separately)
/// var latencyMs: Double = 0
/// let predicted = try await LatencyMeasurer.measure(into: &latencyMs) {
///     try await myModel.predict(input)
/// }
///
/// // Overload 3 — always records latency even if the operation throws
/// var latencyMs: Double = 0
/// let predicted = try await LatencyMeasurer.measureCapturingErrors(into: &latencyMs) {
///     try await myModel.predict(input)
/// }
/// ```
public enum LatencyMeasurer {

    /// Run `operation` and return its result paired with elapsed wall-clock time in milliseconds.
    ///
    /// Use this overload when you want both the result and the latency as a tuple,
    /// without declaring a separate `var latencyMs` binding.
    ///
    /// Uses `CFAbsoluteTimeGetCurrent()` — sub-millisecond precision, on-device only.
    ///
    /// - Parameter operation: The async throwing operation to time.
    /// - Returns: A tuple `(result, latencyMs)` where `latencyMs` is elapsed time in milliseconds.
    /// - Throws: Any error thrown by `operation`. Latency is NOT recorded if the operation throws.
    ///   Use `measureCapturingErrors` if you need latency even on failure.
    public static func measure<T: Sendable>(
        operation: @Sendable () async throws -> T
    ) async rethrows -> (result: T, latencyMs: Double) {
        let start = CFAbsoluteTimeGetCurrent()
        let result = try await operation()
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
        return (result, elapsed)
    }

    /// Run `operation`, store elapsed time into `latencyMs`, and return the result.
    ///
    /// Use this overload when you already have a `var latencyMs: Double = 0` binding
    /// declared in your runner — common when the latency needs to be in scope for
    /// the error-handling path.
    ///
    /// - Parameters:
    ///   - latencyMs: Binding that receives elapsed wall-clock time in milliseconds.
    ///     Not updated if the operation throws. Use `measureCapturingErrors` if you
    ///     need latency even on failure.
    ///   - operation: The async throwing operation to time.
    /// - Returns: The result of `operation`.
    /// - Throws: Any error thrown by `operation`.
    public static func measure<T: Sendable>(
        into latencyMs: inout Double,
        operation: @Sendable () async throws -> T
    ) async rethrows -> T {
        let start = CFAbsoluteTimeGetCurrent()
        let result = try await operation()
        latencyMs = (CFAbsoluteTimeGetCurrent() - start) * 1000
        return result
    }

    /// Run `operation` and always record elapsed time into `latencyMs`, even if it throws.
    ///
    /// Use this overload when error cases must still carry a real latency value in the
    /// evaluation result. This ensures that slow failures are not invisible in P90 metrics.
    ///
    /// - Parameters:
    ///   - latencyMs: Binding that receives elapsed wall-clock time in milliseconds,
    ///                regardless of whether `operation` succeeds or throws.
    ///   - operation: The async throwing operation to measure.
    /// - Returns: The result of `operation` on success.
    /// - Throws: Any error thrown by `operation`.
    ///
    /// - Note: A common mistake is using the non-capturing `measure` overload and then
    ///   falling back to `latencyMs = 0` in the catch block. This makes error cases look
    ///   instantaneous in the P90 chart, hiding slow failures.
    public static func measureCapturingErrors<T: Sendable>(
        into latencyMs: inout Double,
        operation: @Sendable () async throws -> T
    ) async throws -> T {
        let start = CFAbsoluteTimeGetCurrent()
        do {
            let result = try await operation()
            latencyMs = (CFAbsoluteTimeGetCurrent() - start) * 1000
            return result
        } catch {
            latencyMs = (CFAbsoluteTimeGetCurrent() - start) * 1000
            throw error
        }
    }
}
