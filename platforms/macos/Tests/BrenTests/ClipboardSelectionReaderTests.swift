import AppKit
import Testing
@testable import Bren

@MainActor
struct ClipboardSelectionReaderTests {
    @Test
    func neverReturnsClipboardTextWhenCopyDidNotChangeIt() async {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()
        pasteboard.setString("stale clipboard", forType: .string)

        let reader = ClipboardSelectionReader(
            pasteboard: pasteboard,
            timeout: .milliseconds(30),
            pollInterval: .milliseconds(5),
            postCopy: { true }
        )

        #expect(await reader.read() == nil)
        #expect(pasteboard.string(forType: .string) == "stale clipboard")
    }

    @Test
    func readsChangedSelectionAndRestoresOriginalClipboard() async {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()
        pasteboard.setString("original clipboard", forType: .string)

        let reader = ClipboardSelectionReader(
            pasteboard: pasteboard,
            timeout: .milliseconds(200),
            pollInterval: .milliseconds(5),
            postCopy: {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(20))
                    pasteboard.clearContents()
                    pasteboard.setString("fresh selection", forType: .string)
                }
                return true
            }
        )

        #expect(await reader.read() == "fresh selection")
        #expect(pasteboard.string(forType: .string) == "original clipboard")
    }
}
