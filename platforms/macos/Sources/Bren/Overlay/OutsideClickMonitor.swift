import AppKit

@MainActor
final class OutsideClickMonitor {
    nonisolated static let resizeMargin: CGFloat = 8

    nonisolated(unsafe) private var localMonitor: Any?
    nonisolated(unsafe) private var globalMonitor: Any?
    nonisolated(unsafe) private var activationObserver: NSObjectProtocol?

    init(panel: NSPanel, onOutsideClick: @escaping @MainActor () -> Void) {
        localMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak panel] event in
            if let panel,
               panel.isVisible,
               event.window !== panel,
               Self.isOutside(location: NSEvent.mouseLocation, panelFrame: panel.frame) {
                onOutsideClick()
            }
            return event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak panel] _ in
            Task { @MainActor in
                guard let panel, panel.isVisible else { return }
                guard Self.isOutside(location: NSEvent.mouseLocation, panelFrame: panel.frame) else {
                    return
                }
                onOutsideClick()
            }
        }
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak panel] notification in
            let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication
            guard application?.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
            Task { @MainActor in
                guard panel?.isVisible == true else { return }
                onOutsideClick()
            }
        }
    }

    nonisolated static func isOutside(location: CGPoint, panelFrame: CGRect) -> Bool {
        !panelFrame.insetBy(dx: -resizeMargin, dy: -resizeMargin).contains(location)
    }

    deinit {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
        }
    }
}
