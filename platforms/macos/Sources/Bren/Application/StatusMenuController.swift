import AppKit

@MainActor
final class StatusMenuController: NSObject {
    private let statusItem: NSStatusItem
    private let onTranslate: () -> Void
    private let onInput: () -> Void
    private let onRequestAccessibility: () -> Void
    private let onCheckForUpdates: () -> Void
    private let onQuit: () -> Void

    init(
        onTranslate: @escaping () -> Void,
        onInput: @escaping () -> Void,
        onRequestAccessibility: @escaping () -> Void,
        onCheckForUpdates: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.onTranslate = onTranslate
        self.onInput = onInput
        self.onRequestAccessibility = onRequestAccessibility
        self.onCheckForUpdates = onCheckForUpdates
        self.onQuit = onQuit
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        statusItem.button?.image = NSImage(
            systemSymbolName: "character.book.closed.fill",
            accessibilityDescription: "Bren"
        )
        let menu = NSMenu()
        menu.addItem(withTitle: "翻译当前选区  ⌥D", action: #selector(translate), keyEquivalent: "")
        menu.addItem(withTitle: "输入并翻译…", action: #selector(input), keyEquivalent: "")
        menu.addItem(withTitle: "请求辅助功能权限…", action: #selector(requestAccessibility), keyEquivalent: "")
        menu.addItem(withTitle: "检查更新…", action: #selector(checkForUpdates), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出 Bren", action: #selector(quit), keyEquivalent: "q")
        for item in menu.items where item.action != nil {
            item.target = self
        }
        statusItem.menu = menu
    }

    @objc private func translate() {
        onTranslate()
    }

    @objc private func input() {
        onInput()
    }

    @objc private func requestAccessibility() {
        onRequestAccessibility()
    }

    @objc private func checkForUpdates() {
        onCheckForUpdates()
    }

    @objc private func quit() {
        onQuit()
    }
}
