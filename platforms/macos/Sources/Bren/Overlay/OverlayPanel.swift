import AppKit

final class OverlayPanel: NSPanel {
    var onDismiss: (() -> Void)?
    var onCopy: (() -> Void)?
    var onTogglePin: (() -> Void)?
    var onSubmitInput: ((String) -> Void)?
    var onResize: ((CGSize) -> Void)?
    var onResizeEnded: (() -> Void)?
    var interceptsCopyShortcut = true

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
        if interceptsCopyShortcut,
           modifiers.contains(.command),
           event.charactersIgnoringModifiers?.lowercased() == "c" {
            onCopy?()
            return
        }
        super.keyDown(with: event)
    }
}
