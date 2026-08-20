import AppKit
import ScreenCaptureKit

@MainActor
enum BackdropLuminanceSampler {
    private struct CapturedImage: @unchecked Sendable {
        let value: CGImage
    }

    static var hasPermission: Bool {
        CGPreflightScreenCaptureAccess()
    }

    @discardableResult
    static func requestPermissionIfNeeded() -> Bool {
        hasPermission || CGRequestScreenCaptureAccess()
    }

    static func sample(appKitRect: CGRect) async -> Double? {
        guard hasPermission, appKitRect.width > 0, appKitRect.height > 0 else { return nil }
        guard let captureRect = captureRect(for: appKitRect) else { return nil }

        let longestSide: CGFloat = 64
        let scale = min(1, longestSide / max(captureRect.width, captureRect.height))
        let configuration = SCScreenshotConfiguration()
        configuration.width = max(8, Int((captureRect.width * scale).rounded()))
        configuration.height = max(8, Int((captureRect.height * scale).rounded()))
        configuration.showsCursor = false
        configuration.displayIntent = .local
        configuration.dynamicRange = .sdr

        do {
            let captured: CapturedImage = try await withCheckedThrowingContinuation { continuation in
                SCScreenshotManager.captureScreenshot(
                    rect: captureRect,
                    configuration: configuration
                ) { output, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let image = output?.sdrImage {
                        continuation.resume(returning: CapturedImage(value: image))
                    } else {
                        continuation.resume(throwing: CocoaError(.fileReadUnknown))
                    }
                }
            }
            return medianRelativeLuminance(in: captured.value)
        } catch {
            return nil
        }
    }

    static func medianRelativeLuminance(in image: CGImage) -> Double? {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return nil }

        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                | CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
            return nil
        }
        context.interpolationQuality = .low
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        var luminances: [Double] = []
        luminances.reserveCapacity(width * height)
        for offset in stride(from: 0, to: pixels.count, by: 4) {
            let red = linearComponent(Double(pixels[offset]) / 255)
            let green = linearComponent(Double(pixels[offset + 1]) / 255)
            let blue = linearComponent(Double(pixels[offset + 2]) / 255)
            luminances.append(0.2126 * red + 0.7152 * green + 0.0722 * blue)
        }
        luminances.sort()
        return luminances[luminances.count / 2]
    }

    private static func captureRect(for appKitRect: CGRect) -> CGRect? {
        let mainScreen = NSScreen.screens.first { $0.frame.origin == .zero } ?? NSScreen.main
        guard let mainScreen else { return nil }
        return CGRect(
            x: appKitRect.minX,
            y: mainScreen.frame.maxY - appKitRect.maxY,
            width: appKitRect.width,
            height: appKitRect.height
        )
    }

    private static func linearComponent(_ value: Double) -> Double {
        value <= 0.04045
            ? value / 12.92
            : pow((value + 0.055) / 1.055, 2.4)
    }
}
