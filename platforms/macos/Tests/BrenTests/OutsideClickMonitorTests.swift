import CoreGraphics
import Testing
@testable import Bren

struct OutsideClickMonitorTests {
    private let panel = CGRect(x: 100, y: 100, width: 320, height: 160)

    @Test
    func preservesClicksInsidePanelAndResizeMargin() {
        #expect(!OutsideClickMonitor.isOutside(
            location: CGPoint(x: panel.maxX - 1, y: panel.maxY - 1),
            panelFrame: panel
        ))
        #expect(!OutsideClickMonitor.isOutside(
            location: CGPoint(x: panel.maxX + 6, y: panel.midY),
            panelFrame: panel
        ))
    }

    @Test
    func dismissesClicksBeyondResizeMargin() {
        #expect(OutsideClickMonitor.isOutside(
            location: CGPoint(x: panel.maxX + 12, y: panel.midY),
            panelFrame: panel
        ))
    }
}
