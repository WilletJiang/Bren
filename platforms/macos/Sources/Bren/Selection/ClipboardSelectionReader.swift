import AppKit

@MainActor
struct ClipboardSelectionReader {
    private let pasteboard: NSPasteboard
    private let timeout: Duration
    private let pollInterval: Duration
    private let postCopy: @MainActor () -> Bool

    init(
        pasteboard: NSPasteboard,
        timeout: Duration = .milliseconds(750),
        pollInterval: Duration = .milliseconds(10),
        postCopy: @escaping @MainActor () -> Bool
    ) {
        self.pasteboard = pasteboard
        self.timeout = timeout
        self.pollInterval = pollInterval
        self.postCopy = postCopy
    }

    func read() async -> String? {
        guard let snapshot = PasteboardSnapshot(pasteboard: pasteboard) else { return nil }
        let initialChangeCount = pasteboard.changeCount
        guard postCopy() else { return nil }

        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while !Task.isCancelled, clock.now < deadline {
            if pasteboard.changeCount != initialChangeCount {
                let text = pasteboard.string(forType: .string)
                snapshot.restore(to: pasteboard)
                guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    return nil
                }
                return text
            }
            try? await Task.sleep(for: pollInterval)
        }
        return nil
    }
}

private struct PasteboardSnapshot {
    private struct Representation {
        let type: NSPasteboard.PasteboardType
        let data: Data
    }

    private let items: [[Representation]]

    init?(pasteboard: NSPasteboard) {
        guard let pasteboardItems = pasteboard.pasteboardItems else { return nil }
        var capturedItems: [[Representation]] = []
        for item in pasteboardItems {
            var representations: [Representation] = []
            for type in item.types {
                guard let data = item.data(forType: type) else { return nil }
                representations.append(Representation(type: type, data: data))
            }
            capturedItems.append(representations)
        }
        items = capturedItems
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        let restoredItems = items.map { representations in
            let item = NSPasteboardItem()
            for representation in representations {
                item.setData(representation.data, forType: representation.type)
            }
            return item
        }
        if !restoredItems.isEmpty {
            pasteboard.writeObjects(restoredItems)
        }
    }
}
