// EvalKit — all processing is on-device. No data leaves the device.
//
// P90Calculator.swift
// EvalKit/Metrics
//
// Computes the 90th percentile and other descriptive statistics using linear
// interpolation (mirrors numpy.percentile default behaviour).

import Foundation

/// Computes percentiles and descriptive statistics over arrays of `Double`.
///
/// Uses linear interpolation, matching `numpy.percentile()` default method.
/// All computation is pure and on-device.
public enum P90Calculator {

    /// Compute the 90th percentile of `values`.
    ///
    /// Returns `0` when the array is empty.
    public static func p90(_ values: [Double]) -> Double {
        percentile(values, p: 90)
    }

    /// Compute an arbitrary percentile of `values` using linear interpolation.
    ///
    /// - Parameters:
    ///   - values: The data points (any order; sorted internally).
    ///   - p: The desired percentile in the range `[0, 100]`.
    /// - Returns: The interpolated value, or `0` if `values` is empty.
    public static func percentile(_ values: [Double], p: Double) -> Double {
        guard !values.isEmpty else { return 0.0 }
        let sorted = values.sorted()
        let rank = (p / 100.0) * Double(sorted.count - 1)
        let lower = Int(rank.rounded(.down))
        let upper = min(lower + 1, sorted.count - 1)
        let fraction = rank - Double(lower)
        return sorted[lower] + fraction * (sorted[upper] - sorted[lower])
    }

    /// Arithmetic mean. Returns `0` when the array is empty.
    public static func mean(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0.0 }
        return values.reduce(0, +) / Double(values.count)
    }

    /// Population standard deviation (matches `numpy.std` default). Returns `0` when empty.
    public static func standardDeviation(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0.0 }
        let avg = mean(values)
        let variance = values.map { ($0 - avg) * ($0 - avg) }.reduce(0, +) / Double(values.count)
        return variance.squareRoot()
    }
}
