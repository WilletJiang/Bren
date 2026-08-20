import Foundation

struct JSONLBuffer {
    private var storage = Data()

    mutating func append(_ chunk: Data) -> [Data] {
        storage.append(chunk)
        var lines: [Data] = []
        while let newline = storage.firstIndex(of: 0x0A) {
            var line = Data(storage[..<newline])
            storage.removeSubrange(...newline)
            if line.last == 0x0D {
                line.removeLast()
            }
            if !line.isEmpty {
                lines.append(line)
            }
        }
        return lines
    }
}

enum JSONLStreamReader {
    static func read(
        from handle: FileHandle,
        onLine: @escaping @Sendable (Data) async -> Void
    ) async throws {
        var buffer = JSONLBuffer()
        while !Task.isCancelled {
            let chunk = handle.availableData
            guard !chunk.isEmpty else {
                return
            }
            for line in buffer.append(chunk) {
                await onLine(line)
            }
        }
    }
}
