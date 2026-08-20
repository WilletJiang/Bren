import AppKit
import ApplicationServices
import Carbon.HIToolbox

struct Selection {
    let text: String
}

@MainActor
struct SelectionReader {
    @discardableResult
    static func requestAccess(prompt: Bool) -> Bool {
        let options = [
            "AXTrustedCheckOptionPrompt": prompt,
        ] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func read() async throws -> Selection {
        let isTrusted = AXIsProcessTrusted()
        if isTrusted {
            let system = AXUIElementCreateSystemWide()
            var focusedValue: CFTypeRef?
            let focusError = AXUIElementCopyAttributeValue(
                system,
                kAXFocusedUIElementAttribute as CFString,
                &focusedValue
            )
            if focusError == .success, let focusedValue {
                let focusedElement = unsafeDowncast(focusedValue, to: AXUIElement.self)
                var selectedValue: CFTypeRef?
                let selectionError = AXUIElementCopyAttributeValue(
                    focusedElement,
                    kAXSelectedTextAttribute as CFString,
                    &selectedValue
                )
                if selectionError == .success,
                   let text = selectedValue as? String,
                   !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return Selection(text: text)
                }
            }
        }

        if !isTrusted {
            throw SelectionReadError.accessibilityPermissionRequired
        }

        let clipboardReader = ClipboardSelectionReader(
            pasteboard: .general,
            postCopy: Self.postCopyShortcut
        )
        if let copiedText = await clipboardReader.read() {
            return Selection(text: copiedText)
        }
        throw SelectionReadError.noText
    }

    private static func postCopyShortcut() -> Bool {
        guard
            let source = CGEventSource(stateID: .combinedSessionState),
            let keyDown = CGEvent(
                keyboardEventSource: source,
                virtualKey: CGKeyCode(kVK_ANSI_C),
                keyDown: true
            ),
            let keyUp = CGEvent(
                keyboardEventSource: source,
                virtualKey: CGKeyCode(kVK_ANSI_C),
                keyDown: false
            )
        else {
            return false
        }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }
}

enum SelectionReadError: LocalizedError {
    case accessibilityPermissionRequired
    case noText

    var errorDescription: String? {
        switch self {
        case .accessibilityPermissionRequired:
            "Bren 需要辅助功能权限才能读取当前选区。请授权后再次按 ⌥D。"
        case .noText:
            "没有读到选中文本。请重新选择文字后再按 ⌥D。"
        }
    }
}
