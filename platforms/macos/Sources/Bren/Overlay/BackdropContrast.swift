import Foundation

enum ForegroundTone: Equatable {
    case black
    case white
}

enum BackdropContrast {
    // Black and white have equal WCAG contrast at relative luminance ≈ 0.179.
    private static let crossover = 0.179
    private static let switchToWhiteBelow = 0.14
    private static let switchToBlackAbove = 0.23

    static func foreground(for luminance: Double, current: ForegroundTone?) -> ForegroundTone {
        switch current {
        case .black where luminance >= switchToWhiteBelow:
            return .black
        case .white where luminance <= switchToBlackAbove:
            return .white
        default:
            return luminance < crossover ? .white : .black
        }
    }
}
