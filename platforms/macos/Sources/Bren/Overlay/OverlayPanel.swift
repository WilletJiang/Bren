import AppKit

final class OverlayPanel: NSPanel {
    var onDismiss: (() -> Void)?
    var onCopy: (() -> Void)?
    var onTogglePin: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        onDismiss?()
    }

    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if event.keyCode == 53 {
            onDismiss?()
            return
        }
        if modifiers.contains(.command), event.charactersIgnoringModifiers?.lowercased() == "c" {
            onCopy?()
            return
        }
        super.keyDown(with: event)
    }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown, !actionRegion.contains(event.locationInWindow) {
            performDrag(with: event)
            return
        }
        super.sendEvent(event)
    }

    private var actionRegion: CGRect {
        guard frame.width > 84 else { return .null }
        return CGRect(x: max(0, frame.width - 84), y: max(0, frame.height - 42), width: 84, height: 42)
    }
}
