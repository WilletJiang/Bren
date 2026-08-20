import CoreGraphics
import Testing
@testable import Bren

struct OverlayPositionerTests {
    private let screen = CGRect(x: 0, y: 0, width: 1_440, height: 900)
    private let panel = CGSize(width: 480, height: 250)

    @Test
    func placesPanelBelowAndToTheRightOfCursor() {
        let origin = OverlayPositioner.origin(
            anchor: CGPoint(x: 500, y: 600),
            panelSize: panel,
            visibleFrame: screen
        )
        #expect(origin == CGPoint(x: 516, y: 332))
    }

    @Test
    func flipsAboveCursorNearBottomEdge() {
        let origin = OverlayPositioner.origin(
            anchor: CGPoint(x: 500, y: 80),
            panelSize: panel,
            visibleFrame: screen
        )
        #expect(origin.y == 98)
    }

    @Test
    func clampsPanelInsideVisibleFrame() {
        let origin = OverlayPositioner.origin(
            anchor: CGPoint(x: 1_420, y: 880),
            panelSize: panel,
            visibleFrame: screen
        )
        #expect(origin.x == 946)
        #expect(origin.y == 612)
    }
}
