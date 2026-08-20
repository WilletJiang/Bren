import AppKit

final class LiquidGlassHostView: NSGlassEffectView {
    init(content: NSView, cornerRadius: CGFloat = 24) {
        super.init(frame: content.frame)
        style = .clear
        tintColor = nil
        self.cornerRadius = cornerRadius
        contentView = content
        autoresizingMask = [.width, .height]
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }
}
