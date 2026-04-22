// EvalKit — all processing is on-device. No data leaves the device.
//
// LatencyMeasurer.swift
// EvalKit/Metrics
//
// Measures wall-clock latency for async evaluation steps.

import Foundation

/// Measures wall-clock latency for an async operation and returns both the
/// result and the elapsed time in milliseconds.
///
/// Usage:
/// ```swift
/// let (result, latencyMs) = await LatencyMeasurer.measure {
///     try await myModel.predict(input)
/// }
/// ```
public enum LatencyMeasurer {

    /// Run `operation` and return its result paired with elapsed time in milliseconds.
    ///
    /// Uses `CFAbsoluteTimeGetCurrent()` — sub-millisecond precision, on-device only.
    public static func measure<T: Sendable>(
        operation: @Sendable () async throws -> T
    ) async rethrows -> (result: T, latencyMs: Double) {
        let start = CFAbsoluteTimeGetCurrent()
        let result = try await operation()
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
        return (result, elapsed)
    }

    /// Run `operation`, return its result, and record the latency into the provided binding.
    public static func measure<T: Sendable>(
        into latencyMs: inout Double,
        operation: @Sendable () async throws -> T
    ) async rethrows -> T {
        let start = CFAbsoluteTimeGetCurrent()
        let result = try await operation()
        latencyMs = (CFAbsoluteTimeGetCurrent() - start) * 1000
        return result
    }

    /// Run `operation` and always record elapsed time into `latencyMs`, even if the
    /// operation throws. This ensures error cases show real latency in evaluation reports.
    ///
    /// - Parameters:
    ///   - latencyMs: Binding that receives elapsed wall-clock time in milliseconds,
    ///                regardless of whether `operation` succeeds or throws.
    ///   - operation: The async throwing operation to measure.
    /// - Throws: Any error thrown by `operation`.
    /// - Returns: The result of `operation` on success.
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
