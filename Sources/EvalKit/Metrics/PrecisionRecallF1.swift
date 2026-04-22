// EvalKit — all processing is on-device. No data leaves the device.
//
// PrecisionRecallF1.swift
// EvalKit/Metrics
//
// Computes per-class and aggregate precision, recall, and F1 from EvaluationResults.
// Mirrors MetricsCalculator in CMLVSLLM and PrecisionRecallF1 in the existing evaluators.

import Foundation

/// Computes classification metrics: accuracy, per-class P/R/F1, macro and weighted averages.
///
/// All computation is pure and on-device. No data is printed or logged.
public enum PrecisionRecallF1 {

    // MARK: - Per-class metrics

    /// Intermediate per-class breakdown for a single label.
    public struct ClassMetrics: Sendable {
        public let label: String
        public let truePositives: Int
        public let falsePositives: Int
        public let falseNegatives: Int
        /// Number of ground-truth examples with this label.
        public let support: Int

        public var precision: Double {
            let d = truePositives + falsePositives
            return d > 0 ? Double(truePositives) / Double(d) : 0.0
        }

        public var recall: Double {
            let d = truePositives + falseNegatives
            return d > 0 ? Double(truePositives) / Double(d) : 0.0
        }

        public var f1: Double {
            let p = precision, r = recall
            let d = p + r
            return d > 0 ? 2 * p * r / d : 0.0
        }
    }

    // MARK: - Full output

    /// Confusion matrix for a multi-class classification run.
    ///
    /// `matrix[i][j]` is the number of cases where the expected label was
    /// `labels[i]` and the predicted label was `labels[j]`.
    /// The diagonal contains correct predictions; off-diagonal entries are errors.
    ///
    /// Example — 3-class problem, `labels = ["cat", "dog", "bird"]`:
    /// ```
    ///        predicted →
    ///              cat  dog  bird
    /// expected cat [ 5,   1,   0 ]
    ///          dog [ 0,   4,   1 ]
    ///         bird [ 1,   0,   3 ]
    /// ```
    public struct ConfusionMatrix: Sendable {
        /// The ordered label list used as both row (expected) and column (predicted) axes.
        public let labels: [String]
        /// `matrix[row][col]` = count(expected == labels[row] && predicted == labels[col]).
        public let matrix: [[Int]]

        /// Returns the count for a specific expected / predicted label pair.
        public func count(expected: String, predicted: String) -> Int {
            guard let row = labels.firstIndex(of: expected),
                  let col = labels.firstIndex(of: predicted) else { return 0 }
            return matrix[row][col]
        }
    }

    /// Result struct holding per-class breakdown, aggregate scalars, and a confusion matrix.
    public struct Output: Sendable {
        public let accuracy: Double
        public let classMetrics: [ClassMetrics]
        public let macroPrecision: Double
        public let macroRecall: Double
        public let macroF1: Double
        public let weightedPrecision: Double
        public let weightedRecall: Double
        public let weightedF1: Double
        /// Full confusion matrix. Row = expected label, column = predicted label.
        public let confusionMatrix: ConfusionMatrix
    }

    // MARK: - Compute

    /// Compute classification metrics from a batch of results.
    ///
    /// - Parameters:
    ///   - results: Raw results from an `EvaluationRunner`.
    ///   - labels: The complete ordered label vocabulary (all possible classes).
    /// - Returns: `Output` with per-class and aggregate metrics.
    public static func compute(from results: [EvaluationResult], labels: [String]) -> Output {
        let total = results.count
        let correct = results.filter(\.isCorrect).count
        let accuracy = total > 0 ? Double(correct) / Double(total) : 0.0

        let classMetrics: [ClassMetrics] = labels.map { label in
            let support = results.filter { $0.expectedLabel == label }.count
            let tp = results.filter { $0.expectedLabel == label && $0.predictedLabel == label }.count
            let fp = results.filter { $0.expectedLabel != label && $0.predictedLabel == label }.count
            let fn = results.filter { $0.expectedLabel == label && $0.predictedLabel != label }.count
            return ClassMetrics(
                label: label,
                truePositives: tp,
                falsePositives: fp,
                falseNegatives: fn,
                support: support
            )
        }

        let n = Double(labels.count)
        let macroPrecision = classMetrics.map(\.precision).reduce(0, +) / n
        let macroRecall    = classMetrics.map(\.recall).reduce(0, +) / n
        let macroF1        = classMetrics.map(\.f1).reduce(0, +) / n

        let totalSupport = classMetrics.map(\.support).reduce(0, +)
        let (wp, wr, wf): (Double, Double, Double)
        if totalSupport > 0 {
            let w = Double(totalSupport)
            wp = classMetrics.map { Double($0.support) * $0.precision }.reduce(0, +) / w
            wr = classMetrics.map { Double($0.support) * $0.recall    }.reduce(0, +) / w
            wf = classMetrics.map { Double($0.support) * $0.f1        }.reduce(0, +) / w
        } else {
            (wp, wr, wf) = (0, 0, 0)
        }

        // Build confusion matrix: matrix[i][j] = count(expected==labels[i] && predicted==labels[j])
        let labelIndex: [String: Int] = Dictionary(uniqueKeysWithValues: labels.enumerated().map { ($1, $0) })
        var matrix = Array(repeating: Array(repeating: 0, count: labels.count), count: labels.count)
        for result in results {
            guard let expected = result.expectedLabel,
                  let predicted = result.predictedLabel,
                  let row = labelIndex[expected],
                  let col = labelIndex[predicted] else { continue }
            matrix[row][col] += 1
        }
        let confusionMatrix = ConfusionMatrix(labels: labels, matrix: matrix)

        return Output(
            accuracy: accuracy,
            classMetrics: classMetrics,
            macroPrecision: macroPrecision,
            macroRecall: macroRecall,
            macroF1: macroF1,
            weightedPrecision: wp,
            weightedRecall: wr,
            weightedF1: wf,
            confusionMatrix: confusionMatrix
        )
    }
}
