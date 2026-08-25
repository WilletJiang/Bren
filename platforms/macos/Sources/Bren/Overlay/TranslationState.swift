import Combine
import CoreGraphics
import Foundation

enum OverlayMetrics {
    static let loadingSize = CGSize(width: 44, height: 44)
    static let inputSize = CGSize(width: 360, height: 142)
    static let minimumWidth: CGFloat = 220
    static let maximumWidth: CGFloat = 420
    static let minimumResultHeight: CGFloat = 76
    static let maximumHeight: CGFloat = 220
    static let maximumUserWidth: CGFloat = 720
    static let maximumUserHeight: CGFloat = 560
}

@MainActor
final class TranslationState: ObservableObject {
    enum Phase: Equatable {
        case idle
        case input
        case translating
        case completed
        case failed(String)
    }

    @Published private(set) var output = ""
    @Published private(set) var draft = ""
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var isPinned = false

    var isLoadingOrb: Bool {
        phase == .translating && output.isEmpty
    }

    var isInputMode: Bool {
        phase == .input
    }

    var preferredSize: CGSize {
        switch phase {
        case .idle:
            OverlayMetrics.loadingSize
        case .input:
            OverlayMetrics.inputSize
        case .translating where output.isEmpty:
            OverlayMetrics.loadingSize
        case let .failed(message):
            resultSize(for: message)
        default:
            resultSize(for: output)
        }
    }

    func begin() {
        output = ""
        draft = ""
        phase = .translating
    }

    func beginInput() {
        output = ""
        draft = ""
        phase = .input
    }

    func updateDraft(_ text: String) {
        draft = text
    }

    func submitInput() -> String? {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        output = ""
        draft = ""
        phase = .translating
        return text
    }

    func append(_ delta: String) {
        output += delta
    }

    func complete(text: String) {
        output = text
        phase = .completed
    }

    func fail(_ message: String) {
        output = ""
        phase = .failed(message)
    }

    func togglePinned() {
        isPinned.toggle()
    }

    private func resultSize(for text: String) -> CGSize {
        let logicalLines = text.split(separator: "\n", omittingEmptySubsequences: false)
        let columnCounts = logicalLines.map { line in
            line.unicodeScalars.reduce(0) { partial, scalar in
                partial + (scalar.value < 128 ? 1 : 2)
            }
        }
        let longestLine = max(1, columnCounts.max() ?? 1)
        let width = min(
            OverlayMetrics.maximumWidth,
            max(OverlayMetrics.minimumWidth, CGFloat(min(longestLine, 48)) * 7.6 + 40)
        )
        let columnsPerLine = max(20, Int((width - 36) / 7.6))
        let renderedLines = columnCounts.reduce(0) { total, columns in
            total + max(1, Int(ceil(Double(columns) / Double(columnsPerLine))))
        }
        let formulaAllowance: CGFloat = containsDisplayFormula(text) ? 58 : 0
        let height = min(
            OverlayMetrics.maximumHeight,
            max(
                OverlayMetrics.minimumResultHeight,
                CGFloat(renderedLines) * 24 + 32 + formulaAllowance
            )
        )
        return CGSize(width: width.rounded(.up), height: height.rounded(.up))
    }

    private func containsDisplayFormula(_ text: String) -> Bool {
        text.contains("$$") || text.contains(#"\["#) || text.contains(#"\begin{"#)
    }
}
