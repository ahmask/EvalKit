// EvalKit — all processing is on-device. No data leaves the device.
//
// ConfusionMatrix.swift
// EvalKitClassification/Metrics
//
// Confusion matrix for a multi-class classification run.

import Foundation

/// A confusion matrix for a multi-class classification evaluation.
///
/// ## Purpose
///
/// A confusion matrix lets you see not just *how many* predictions were wrong,
/// but *which classes are being confused with which*. Accuracy tells you the
/// overall error rate. A confusion matrix tells you whether the model consistently
/// mistakes "baggage" for "seating", or whether errors are scattered randomly —
/// two very different problems requiring very different fixes.
///
/// ## When to use
///
/// Read the confusion matrix from `PrecisionRecallF1.Output.confusionMatrix` after
/// running `PrecisionRecallF1.compute(from:labels:)`. Use it during debugging to:
/// - Identify which label pairs the model most frequently confuses.
/// - Find classes the model never predicts (an all-zero column).
/// - Spot classes the model always over-predicts (a large off-diagonal column total).
///
/// ## When not to use
///
/// `ConfusionMatrix` is only meaningful for single-label classification. For
/// multi-label classification (multiple labels per example), use
/// `MultiLabelClassificationReporter` and inspect per-label F1 scores instead.
/// For binary classification error analysis, `FalseRateCalculator` is more direct.
///
/// ## Usage example
///
/// ```swift
/// let output = PrecisionRecallF1.compute(from: results, labels: ["cat", "dog", "bird"])
/// let matrix = output.confusionMatrix
///
/// // How many times did the model predict "dog" when the answer was "cat"?
/// let catAsDog = matrix.count(expected: "cat", predicted: "dog")
///
/// // Print the full matrix row by row
/// for expected in matrix.labels {
///     let row = matrix.labels.map { predicted in
///         matrix.count(expected: expected, predicted: predicted)
///     }
///     print("\(expected): \(row)")
/// }
/// ```
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
///
/// Interpret the matrix row-by-row: each row represents the ground-truth class,
/// each column represents what the model predicted. A cell at (i, j) where i ≠ j
/// indicates a misclassification — the model confused class `labels[i]` with `labels[j]`.
public struct ConfusionMatrix: Sendable {

    // MARK: - Properties

    /// The ordered label list used as both row (expected) and column (predicted) axes.
    ///
    /// Pass the same `labels` array you gave to `PrecisionRecallF1.compute(from:labels:)`.
    /// The order determines row and column indices — `labels[i]` is the i-th row (expected class)
    /// and the i-th column (predicted class).
    public let labels: [String]

    /// `matrix[row][col]` = count(expected == labels[row] && predicted == labels[col]).
    ///
    /// The diagonal (`matrix[i][i]`) holds correct predictions for `labels[i]`.
    /// All off-diagonal cells represent misclassifications. A cell with a large
    /// off-diagonal value signals a systematic confusion between two classes.
    public let matrix: [[Int]]

    // MARK: - Init

    /// Create a confusion matrix.
    ///
    /// In practice you receive a `ConfusionMatrix` from `PrecisionRecallF1.Output.confusionMatrix`
    /// rather than constructing one manually.
    ///
    /// - Parameters:
    ///   - labels: The ordered label vocabulary.
    ///   - matrix: A square 2D array where `matrix[i][j]` is the count for
    ///     expected = `labels[i]`, predicted = `labels[j]`.
    public init(labels: [String], matrix: [[Int]]) {
        self.labels = labels
        self.matrix = matrix
    }

    // MARK: - Accessors

    /// Returns the count for a specific expected / predicted label pair.
    ///
    /// Use this to answer targeted questions: "How many times did the model predict
    /// `predicted` when the ground truth was `expected`?"
    ///
    /// - Parameters:
    ///   - expected: The ground-truth label string.
    ///   - predicted: The model-predicted label string.
    /// - Returns: The number of cases matching this pair, or `0` if either label
    ///   is not in the vocabulary. Does not throw for unknown labels — check the
    ///   `labels` array first if you need to distinguish "zero occurrences" from
    ///   "label not in vocabulary".
    public func count(expected: String, predicted: String) -> Int {
        guard let row = labels.firstIndex(of: expected),
              let col = labels.firstIndex(of: predicted) else { return 0 }
        return matrix[row][col]
    }
}
