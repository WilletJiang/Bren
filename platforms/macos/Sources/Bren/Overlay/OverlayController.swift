import AppKit
import QuartzCore
import SwiftUI

struct OverlayPositioner {
    static func origin(anchor: CGPoint, panelSize: CGSize, visibleFrame: CGRect) -> CGPoint {
        let margin: CGFloat = 14
        var x = anchor.x + 16
        var y = anchor.y - panelSize.height - 18

        if y < visibleFrame.minY + margin {
            y = anchor.y + 18
        }
        x = min(max(x, visibleFrame.minX + margin), visibleFrame.maxX - panelSize.width - margin)
        y = min(max(y, visibleFrame.minY + margin), visibleFrame.maxY - panelSize.height - margin)
        return CGPoint(x: x, y: y)
    }
}

@MainActor
final class OverlayController: NSObject, NSWindowDelegate {
    var onDismiss: (() -> Void)?
    var onSubmitInput: ((String) -> Void)?

    private let state: TranslationState
    private let panel: OverlayPanel
    private let hostingView: NSHostingView<TranslationView>
    private let glassView: LiquidGlassHostView
    private var anchor = CGPoint.zero
    private var userDragged = false
    private var userResized = false
    private var isProgrammaticMove = false
    private var isDismissing = false
    private var resizeStartFrame: CGRect?
    private var animationGeneration = 0
    private var outsideClickMonitor: OutsideClickMonitor?

    override init() {
        let state = TranslationState()
        let initialSize = OverlayMetrics.loadingSize
        let panel = OverlayPanel(
            contentRect: CGRect(origin: .zero, size: initialSize),
            styleMask: [.borderless, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )
        let copy = {
            guard !state.output.isEmpty else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(state.output, forType: .string)
        }
        let rootView = TranslationView(
            state: state,
            onClose: { panel.onDismiss?() },
            onCopy: { panel.onCopy?() },
            onTogglePin: { panel.onTogglePin?() },
            onSubmitInput: { panel.onSubmitInput?($0) },
            onResize: { panel.onResize?($0) },
            onResizeEnded: { panel.onResizeEnded?() }
        )
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = CGRect(origin: .zero, size: initialSize)
        hostingView.autoresizingMask = [.width, .height]
        let glassView = LiquidGlassHostView(content: hostingView)
        glassView.frame = CGRect(origin: .zero, size: initialSize)
        glassView.cornerRadius = initialSize.height / 2

        self.state = state
        self.panel = panel
        self.hostingView = hostingView
        self.glassView = glassView
        super.init()

        panel.contentView = glassView
        panel.delegate = self
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isMovable = true
        panel.isMovableByWindowBackground = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.animationBehavior = .none
        panel.onDismiss = { [weak self] in self?.dismissAnimated() }
        panel.onCopy = copy
        panel.onTogglePin = { [weak self] in self?.togglePinned() }
        panel.onSubmitInput = { [weak self] text in
            guard let self else { return }
            self.userResized = false
            self.panel.interceptsCopyShortcut = true
            self.resizeAndPosition(animated: true, duration: 0.24)
            self.onSubmitInput?(text)
        }
        panel.onResize = { [weak self] translation in
            self?.resizePanel(by: translation)
        }
        panel.onResizeEnded = { [weak self] in
            self?.resizeStartFrame = nil
        }
        outsideClickMonitor = OutsideClickMonitor(panel: panel) { [weak self] in
            guard let self, !self.state.isPinned else { return }
            self.dismissAnimated()
        }
    }

    func begin() {
        begin(at: NSEvent.mouseLocation)
    }

    private func begin(at point: CGPoint) {
        anchor = point
        userDragged = false
        userResized = false
        isDismissing = false
        panel.interceptsCopyShortcut = true
        state.begin()
        presentLoadingOrb()
    }

    func showInput() {
        anchor = NSEvent.mouseLocation
        userDragged = false
        userResized = false
        isDismissing = false
        panel.interceptsCopyShortcut = false
        state.beginInput()
        presentInputPanel()
    }

    func append(_ text: String) {
        let wasLoadingOrb = state.isLoadingOrb
        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
            state.append(text)
        }
        resizeAndPosition(animated: true, duration: wasLoadingOrb ? 0.36 : 0.14)
    }

    func complete(text: String) {
        let wasLoadingOrb = state.isLoadingOrb
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            state.complete(text: text)
        }
        resizeAndPosition(animated: true, duration: wasLoadingOrb ? 0.36 : 0.18)
    }

    func fail(_ message: String) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            state.fail(message)
        }
        resizeAndPosition(animated: true, duration: 0.3)
        panel.makeKeyAndOrderFront(nil)
    }

    func showError(_ message: String) {
        anchor = NSEvent.mouseLocation
        userDragged = false
        userResized = false
        panel.interceptsCopyShortcut = true
        state.begin()
        presentLoadingOrb()
        fail(message)
    }

    func showPreview() {
        let frame = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1_440, height: 900)
        begin(at: CGPoint(x: frame.minX + 104, y: frame.maxY - 102))
        if !state.isPinned {
            state.togglePinned()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { [weak self] in
            self?.complete(text: "质量与能量满足 $E = mc^2$，二次方程的解为 $$x = \\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}$$")
        }
    }

    func windowDidMove(_ notification: Notification) {
        if !isProgrammaticMove {
            userDragged = true
        }
    }

    func windowDidResize(_ notification: Notification) {
        guard !isProgrammaticMove, panel.isVisible, !state.isLoadingOrb else { return }
        userResized = true
        glassView.cornerRadius = 24
    }

    private func presentLoadingOrb() {
        animationGeneration += 1
        panel.alphaValue = 1
        let targetSize = OverlayMetrics.loadingSize
        configureResizeLimits(for: targetSize, allowsUserResize: false)
        let targetOrigin = targetOrigin(for: targetSize)
        let startSize = CGSize(width: 24, height: 24)
        let startOrigin = CGPoint(
            x: targetOrigin.x + (targetSize.width - startSize.width) / 2,
            y: targetOrigin.y + (targetSize.height - startSize.height) / 2
        )
        setGeometry(size: startSize, origin: startOrigin, cornerRadius: 12)
        panel.makeKeyAndOrderFront(nil)
        animateGeometry(
            size: targetSize,
            origin: targetOrigin,
            cornerRadius: targetSize.height / 2,
            duration: 0.24
        )
    }

    private func presentInputPanel() {
        animationGeneration += 1
        panel.alphaValue = 1
        let targetSize = OverlayMetrics.inputSize
        configureResizeLimits(for: targetSize, allowsUserResize: true)
        let targetOrigin = targetOrigin(for: targetSize)
        let startSize = OverlayMetrics.loadingSize
        let startOrigin = CGPoint(
            x: targetOrigin.x + (targetSize.width - startSize.width) / 2,
            y: targetOrigin.y + (targetSize.height - startSize.height) / 2
        )
        setGeometry(size: startSize, origin: startOrigin, cornerRadius: 22)
        NSApplication.shared.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        animateGeometry(
            size: targetSize,
            origin: targetOrigin,
            cornerRadius: 24,
            duration: 0.26
        )
    }

    private func resizeAndPosition(animated: Bool, duration: TimeInterval) {
        let preferredSize = state.preferredSize
        configureResizeLimits(for: preferredSize, allowsUserResize: !state.isLoadingOrb)
        let size = userResized && panel.isVisible && !state.isLoadingOrb
            ? panel.frame.size
            : preferredSize
        let origin = targetOrigin(for: size)
        let radius = state.isLoadingOrb ? size.height / 2 : 24
        if animated {
            animateGeometry(size: size, origin: origin, cornerRadius: radius, duration: duration)
        } else {
            setGeometry(size: size, origin: origin, cornerRadius: radius)
        }
    }

    private func dismissAnimated() {
        guard panel.isVisible, !isDismissing else { return }
        isDismissing = true
        onDismiss?()
        let endSize = CGSize(
            width: panel.frame.width * 0.97,
            height: panel.frame.height * 0.97
        )
        let endOrigin = CGPoint(
            x: panel.frame.midX - endSize.width / 2,
            y: panel.frame.midY - endSize.height / 2
        )
        animateGeometry(
            size: endSize,
            origin: endOrigin,
            cornerRadius: state.isLoadingOrb ? endSize.height / 2 : 23,
            duration: 0.16,
            targetAlpha: 0
        ) { [weak self] in
            self?.panel.orderOut(nil)
            self?.panel.alphaValue = 1
            self?.isDismissing = false
        }
    }

    private func targetOrigin(for size: CGSize) -> CGPoint {
        let visibleFrame = currentScreen()?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1_440, height: 900)
        if (userDragged || userResized), panel.isVisible {
            let margin: CGFloat = 14
            let x = min(max(panel.frame.minX, visibleFrame.minX + margin), visibleFrame.maxX - size.width - margin)
            let y = min(
                max(panel.frame.maxY - size.height, visibleFrame.minY + margin),
                visibleFrame.maxY - size.height - margin
            )
            return CGPoint(x: x, y: y)
        }
        return OverlayPositioner.origin(anchor: anchor, panelSize: size, visibleFrame: visibleFrame)
    }

    private func currentScreen() -> NSScreen? {
        if (userDragged || userResized), panel.isVisible {
            let center = CGPoint(x: panel.frame.midX, y: panel.frame.midY)
            return NSScreen.screens.first { NSMouseInRect(center, $0.frame, false) }
        }
        return NSScreen.screens.first { NSMouseInRect(anchor, $0.frame, false) } ?? NSScreen.main
    }

    private func togglePinned() {
        state.togglePinned()
    }

    private func configureResizeLimits(for size: CGSize, allowsUserResize: Bool) {
        if allowsUserResize {
            panel.contentMinSize = CGSize(
                width: OverlayMetrics.minimumWidth,
                height: OverlayMetrics.minimumResultHeight
            )
            let visibleSize = currentScreen()?.visibleFrame.size
                ?? CGSize(width: OverlayMetrics.maximumUserWidth, height: OverlayMetrics.maximumUserHeight)
            panel.contentMaxSize = CGSize(
                width: min(
                    OverlayMetrics.maximumUserWidth,
                    max(OverlayMetrics.minimumWidth, visibleSize.width - 28)
                ),
                height: min(
                    OverlayMetrics.maximumUserHeight,
                    max(OverlayMetrics.minimumResultHeight, visibleSize.height - 28)
                )
            )
        } else {
            panel.contentMinSize = size
            panel.contentMaxSize = size
        }
    }

    private func resizePanel(by translation: CGSize) {
        guard !state.isLoadingOrb else { return }
        let startFrame: CGRect
        if let resizeStartFrame {
            startFrame = resizeStartFrame
        } else {
            startFrame = panel.frame
            resizeStartFrame = startFrame
        }

        let width = min(
            panel.contentMaxSize.width,
            max(panel.contentMinSize.width, startFrame.width + translation.width)
        )
        let height = min(
            panel.contentMaxSize.height,
            max(panel.contentMinSize.height, startFrame.height + translation.height)
        )
        let size = CGSize(width: width, height: height)
        let origin = CGPoint(x: startFrame.minX, y: startFrame.maxY - height)

        userResized = true
        isProgrammaticMove = true
        hostingView.frame = CGRect(origin: .zero, size: size)
        glassView.frame = CGRect(origin: .zero, size: size)
        glassView.cornerRadius = 24
        panel.setFrame(CGRect(origin: origin, size: size), display: true, animate: false)
        isProgrammaticMove = false
    }

    private func setGeometry(size: CGSize, origin: CGPoint, cornerRadius: CGFloat) {
        animationGeneration += 1
        isProgrammaticMove = true
        hostingView.frame = CGRect(origin: .zero, size: size)
        glassView.frame = CGRect(origin: .zero, size: size)
        glassView.cornerRadius = cornerRadius
        panel.setFrame(CGRect(origin: origin, size: size), display: true, animate: false)
        isProgrammaticMove = false
    }

    private func animateGeometry(
        size: CGSize,
        origin: CGPoint,
        cornerRadius: CGFloat,
        duration: TimeInterval,
        targetAlpha: CGFloat = 1,
        completion: (@MainActor @Sendable () -> Void)? = nil
    ) {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            setGeometry(size: size, origin: origin, cornerRadius: cornerRadius)
            completion?()
            return
        }

        animationGeneration += 1
        let generation = animationGeneration
        isProgrammaticMove = true
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            hostingView.animator().frame = CGRect(origin: .zero, size: size)
            glassView.animator().frame = CGRect(origin: .zero, size: size)
            glassView.animator().cornerRadius = cornerRadius
            panel.animator().setFrame(CGRect(origin: origin, size: size), display: true)
            panel.animator().alphaValue = targetAlpha
        } completionHandler: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                guard self.animationGeneration == generation else { return }
                self.isProgrammaticMove = false
                completion?()
            }
        }
    }
}
