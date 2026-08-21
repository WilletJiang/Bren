import AppKit

@MainActor
final class AppCoordinator {
    private let core = CoreClient()
    private let overlay = OverlayController()
    private let selectionReader = SelectionReader()
    private let updates = UpdateController()
    private var hotKey: GlobalHotKey?
    private var statusMenu: StatusMenuController?
    private var currentRequestID: String?
    private var requestWatchdog: Task<Void, Never>?

    func start() {
        overlay.onDismiss = { [weak self] in
            self?.cancelCurrentTranslation()
        }
        overlay.onSubmitInput = { [weak self] text in
            self?.beginInputTranslation(text)
        }
        statusMenu = StatusMenuController(
            onTranslate: { [weak self] in
                Task { @MainActor in await self?.translateSelection() }
            },
            onInput: { [weak self] in self?.showInput() },
            onRequestAccessibility: { SelectionReader.requestAccess(prompt: true) },
            onCheckForUpdates: { [weak self] in self?.updates.checkForUpdates() },
            onQuit: { NSApplication.shared.terminate(nil) }
        )

        let arguments = CommandLine.arguments
        if arguments.contains("--preview") {
            NSApplication.shared.setActivationPolicy(.regular)
            overlay.showPreview()
            return
        }

        core.onSystemEvent = { [weak self] event in
            guard event.event == "error", let error = event.error else { return }
            self?.overlay.showError(error.message)
        }

        if arguments.contains("--e2e-preview") {
            NSApplication.shared.setActivationPolicy(.regular)
            do {
                try core.start()
                beginTranslation(Selection(
                    text: "Liquid Glass dynamically bends light while keeping the content beneath it visible."
                ))
            } catch {
                overlay.showError(error.localizedDescription)
            }
            return
        }

        SelectionReader.requestAccess(prompt: true)

        do {
            try core.start()
            hotKey = try GlobalHotKey { [weak self] in
                Task { @MainActor in await self?.translateSelection() }
            }
        } catch {
            overlay.showError(error.localizedDescription)
        }
    }

    func stop() {
        clearRequestWatchdog()
        core.stop()
        hotKey?.invalidate()
        hotKey = nil
    }

    private func translateSelection() async {
        do {
            let selection = try await selectionReader.read()
            beginTranslation(selection)
        } catch is SelectionReadError {
            showInput()
        } catch {
            overlay.showError(error.localizedDescription)
        }
    }

    private func showInput() {
        cancelCurrentTranslation()
        overlay.showInput()
    }

    private func beginTranslation(_ selection: Selection) {
        cancelCurrentTranslation()
        overlay.begin()
        startTranslation(selection.text)
    }

    private func beginInputTranslation(_ text: String) {
        cancelCurrentTranslation()
        startTranslation(text)
    }

    private func startTranslation(_ text: String) {
        do {
            let requestID = try core.translate(text) { [weak self] event in
                guard let self, event.id == self.currentRequestID else { return }
                switch event.event {
                case "started":
                    self.startFirstTokenWatchdog(for: event.id)
                case "delta":
                    if let text = event.data?.text {
                        self.clearRequestWatchdog()
                        self.overlay.append(text)
                    }
                case "completed":
                    self.clearRequestWatchdog()
                    self.overlay.complete(text: event.data?.text ?? "")
                    self.currentRequestID = nil
                case "cancelled":
                    self.clearRequestWatchdog()
                    self.currentRequestID = nil
                case "error":
                    self.clearRequestWatchdog()
                    self.overlay.fail(event.error?.message ?? "翻译失败")
                    self.currentRequestID = nil
                default:
                    break
                }
            }
            currentRequestID = requestID
            startAcceptanceWatchdog(for: requestID)
        } catch {
            overlay.fail(error.localizedDescription)
        }
    }

    private func cancelCurrentTranslation() {
        guard let currentRequestID else { return }
        self.currentRequestID = nil
        clearRequestWatchdog()
        core.cancel(currentRequestID)
    }

    private func startAcceptanceWatchdog(for requestID: String) {
        clearRequestWatchdog()
        requestWatchdog = Task { [weak self] in
            try? await Task.sleep(for: .seconds(20))
            guard !Task.isCancelled, let self, self.currentRequestID == requestID else { return }
            self.requestWatchdog = nil
            self.cancelCurrentTranslation()
            self.overlay.fail("Codex 后端启动超时，请重试")
        }
    }

    private func startFirstTokenWatchdog(for requestID: String?) {
        guard let requestID else { return }
        clearRequestWatchdog()
        requestWatchdog = Task { [weak self] in
            try? await Task.sleep(for: .seconds(15))
            guard !Task.isCancelled, let self, self.currentRequestID == requestID else { return }
            self.requestWatchdog = nil
            self.cancelCurrentTranslation()
            self.overlay.fail("Codex 15 秒内没有返回内容，请重试")
        }
    }

    private func clearRequestWatchdog() {
        requestWatchdog?.cancel()
        requestWatchdog = nil
    }
}
