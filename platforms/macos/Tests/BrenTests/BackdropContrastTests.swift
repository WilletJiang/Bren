import CoreGraphics
import Testing
@testable import Bren

struct BackdropContrastTests {
    @Test
    func choosesWhiteForDarkAndBlackForLight() {
        #expect(BackdropContrast.foreground(for: 0.02, current: nil) == .white)
        #expect(BackdropContrast.foreground(for: 0.80, current: nil) == .black)
    }

    @Test
    func usesHysteresisAroundTheCrossover() {
        #expect(BackdropContrast.foreground(for: 0.18, current: .black) == .black)
        #expect(BackdropContrast.foreground(for: 0.18, current: .white) == .white)
        #expect(BackdropContrast.foreground(for: 0.10, current: .black) == .white)
        #expect(BackdropContrast.foreground(for: 0.30, current: .white) == .black)
    }

    @Test
    @MainActor
    func measuresKnownBlackAndWhiteImages() throws {
        let black = try image(filledWith: gray(0))
        let white = try image(filledWith: gray(1))
        #expect(BackdropLuminanceSampler.medianRelativeLuminance(in: black) == 0)
        #expect(BackdropLuminanceSampler.medianRelativeLuminance(in: white) == 1)
    }

    private func image(filledWith color: CGColor) throws -> CGImage {
        let context = try #require(CGContext(
            data: nil,
            width: 4,
            height: 4,
            bitsPerComponent: 8,
            bytesPerRow: 16,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                | CGBitmapInfo.byteOrder32Big.rawValue
        ))
        context.setFillColor(color)
        context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        return try #require(context.makeImage())
    }

    private func gray(_ value: CGFloat) -> CGColor {
        CGColor(gray: value, alpha: 1)
    }
}
