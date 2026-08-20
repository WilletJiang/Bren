import Foundation

@MainActor
final class CoreClient {
    typealias EventHandler = (CoreEvent) -> Void

    var onSystemEvent: EventHandler?

    private var process: Process?
    private var inputHandle: FileHandle?
    private var outputTask: Task<Void, Never>?
    private var errorTask: Task<Void, Never>?
    private var handlers: [String: EventHandler] = [:]

    func start() throws {
        guard process == nil else { return }

        let process = Process()
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.executableURL = try CoreLocator.executableURL()
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        try process.run()

        self.process = process
        inputHandle = inputPipe.fileHandleForWriting
        outputTask = Task.detached { [weak self] in
            guard let client = self else { return }
            do {
                try await JSONLStreamReader.read(from: outputPipe.fileHandleForReading) { data in
                    do {
                        let event = try JSONDecoder().decode(CoreEvent.self, from: data)
                        await client.receive(event)
                    } catch {
                        await client.emitProtocolError(error)
                    }
                }
                if !Task.isCancelled {
                    await client.coreDidStop()
                }
            } catch {
                if !Task.isCancelled {
                    await client.emitProtocolError(error)
                }
            }
        }
        errorTask = Task.detached {
            do {
                try await JSONLStreamReader.read(from: errorPipe.fileHandleForReading) { data in
                    var diagnostic = Data("[bren-core] ".utf8)
                    diagnostic.append(data)
                    diagnostic.append(0x0A)
                    try? FileHandle.standardError.write(contentsOf: diagnostic)
                }
            } catch {
                // Stderr is diagnostic only; stdout carries the stable protocol.
            }
        }
    }

    func translate(_ text: String, handler: @escaping EventHandler) throws -> String {
        let requestID = UUID().uuidString.lowercased()
        handlers[requestID] = handler
        let request = CoreRequest(
            id: requestID,
            method: "translate",
            params: TranslateRequestParameters(text: text)
        )
        try send(request)
        return requestID
    }

    func cancel(_ requestID: String) {
        handlers.removeValue(forKey: requestID)
        let request = CoreRequest(
            id: UUID().uuidString.lowercased(),
            method: "cancel",
            params: CancelRequestParameters(requestId: requestID)
        )
        try? send(request)
    }

    func stop() {
        let runningProcess = process
        process = nil
        outputTask?.cancel()
        errorTask?.cancel()
        outputTask = nil
        errorTask = nil
        try? inputHandle?.close()
        inputHandle = nil
        if runningProcess?.isRunning == true {
            runningProcess?.terminate()
        }
        handlers.removeAll()
    }

    private func send<Parameters>(_ request: CoreRequest<Parameters>) throws {
        guard let inputHandle else {
            throw CoreClientError.notRunning
        }
        var data = try JSONEncoder().encode(request)
        data.append(0x0A)
        try inputHandle.write(contentsOf: data)
    }

    private func receive(_ event: CoreEvent) {
        guard let id = event.id else {
            onSystemEvent?(event)
            return
        }
        handlers[id]?(event)
        if ["completed", "cancelled", "error"].contains(event.event) {
            handlers.removeValue(forKey: id)
        }
    }

    private func emitProtocolError(_ error: Error) {
        let event = CoreEvent(
            v: 1,
            id: nil,
            event: "error",
            data: nil,
            error: CoreErrorData(
                code: "protocol_error",
                message: error.localizedDescription,
                retryable: true
            )
        )
        onSystemEvent?(event)
    }

    private func coreDidStop() {
        guard process != nil else { return }
        process = nil
        inputHandle = nil
        handlers.removeAll()
        emitProtocolError(CoreClientError.stoppedUnexpectedly)
    }

}

enum CoreClientError: LocalizedError {
    case notRunning
    case stoppedUnexpectedly

    var errorDescription: String? {
        switch self {
        case .notRunning:
            "bren-core 尚未运行"
        case .stoppedUnexpectedly:
            "bren-core 意外停止"
        }
    }
}
