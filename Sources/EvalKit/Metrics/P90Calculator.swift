// EvalKit — all processing is on-device. No data leaves the device.
//
// P90Calculator.swift
// EvalKit/Metrics
//
// Computes the 90th percentile and other descriptive statistics using linear
// interpolation (mirrors numpy.percentile default behaviour).

import Foundation

/// Computes percentiles, mean, and standard deviation over arrays of `Double`.
///
/// ## Purpose
///
/// `P90Calculator` is the shared statistics utility used by every reporter in EvalKit
/// to aggregate latency, similarity score, and other per-case numeric values into
/// the scalar metrics that appear in `EvaluationMetrics`. All computation is pure
/// and on-device; no values are printed or logged.
///
/// ## When to use
///
/// Call `P90Calculator` inside your `EvaluationReporter` implementation to compute
/// distribution metrics from a `[Double]` array of per-case values:
///
/// ```swift
/// let latencies = results.map(\.latencyMs)
/// let mean = P90Calculator.mean(latencies)          // → latencyMsMean
/// let p90  = P90Calculator.p90(latencies)           // → latencyMsP90
/// let std  = P90Calculator.standardDeviation(latencies)  // → scoreStd
/// ```
///
/// ## When not to use
///
/// `P90Calculator` operates on raw `[Double]` arrays. It has no knowledge of what
/// the numbers represent. Do not use it for categorical data or for computing metrics
/// that require label information — use `PrecisionRecallF1` or `FalseRateCalculator`
/// for those.
public enum P90Calculator {

    /// Compute the 90th percentile of `values`.
    ///
    /// The 90th percentile means 90% of values in the array fall below this threshold.
    /// For latency arrays, this is the UX-relevant worst-case metric: one in ten
    /// users experiences at least this much delay.
    ///
    /// - Parameter values: The data points to analyse (any order).
    /// - Returns: The 90th-percentile value using linear interpolation, or `0` if `values` is empty.
    public static func p90(_ values: [Double]) -> Double {
        percentile(values, p: 90)
    }

    /// Compute an arbitrary percentile of `values` using linear interpolation.
    ///
    /// Matches the behaviour of `numpy.percentile()` default method (linear interpolation
    /// between adjacent sorted values).
    ///
    /// - Parameters:
    ///   - values: The data points (any order; sorted internally).
    ///   - p: The desired percentile in the range `[0, 100]`. E.g. `50` for the median.
    /// - Returns: The interpolated value at percentile `p`, or `0` if `values` is empty.
    ///
    /// - Note: Passing `p` outside `[0, 100]` does not throw but produces an extrapolated
    ///   result — clamp `p` to `[0, 100]` before calling if the input is user-supplied.
    public static func percentile(_ values: [Double], p: Double) -> Double {
        guard !values.isEmpty else { return 0.0 }
        let sorted = values.sorted()
        let rank = (p / 100.0) * Double(sorted.count - 1)
        let lower = Int(rank.rounded(.down))
        let upper = min(lower + 1, sorted.count - 1)
        let fraction = rank - Double(lower)
        return sorted[lower] + fraction * (sorted[upper] - sorted[lower])
    }

    /// Arithmetic mean of `values`. Returns `0` when the array is empty.
    ///
    /// Used for `latencyMsMean`, `scoreMean`, and other average metrics in `EvaluationMetrics`.
    ///
    /// - Parameter values: The data points to average.
    /// - Returns: The arithmetic mean, or `0` if `values` is empty.
    public static func mean(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0.0 }
        return values.reduce(0, +) / Double(values.count)
    }

    /// Population standard deviation of `values`. Returns `0` when the array is empty.
    ///
    /// Matches `numpy.std()` default (population, not sample). Used for `scoreStd` and
    /// `secondaryScoreStd` in `EvaluationMetrics`. A low std indicates consistent quality
    /// across cases; a high std indicates high variance worth investigating.
    ///
    /// - Parameter values: The data points to analyse.
    /// - Returns: The population standard deviation, or `0` if `values` is empty.
    public static func standardDeviation(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0.0 }
        let avg = mean(values)
        let variance = values.map { ($0 - avg) * ($0 - avg) }.reduce(0, +) / Double(values.count)
        return variance.squareRoot()
    }
}
