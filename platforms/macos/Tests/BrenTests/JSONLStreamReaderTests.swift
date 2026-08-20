import Foundation
import Testing
@testable import Bren

struct JSONLStreamReaderTests {
    @Test
    func reconstructsFragmentedLines() {
        var buffer = JSONLBuffer()
        #expect(buffer.append(Data("{\"event\":\"del".utf8)).isEmpty)
        let lines = buffer.append(Data("ta\"}\n".utf8))
        #expect(lines.map { String(decoding: $0, as: UTF8.self) } == ["{\"event\":\"delta\"}"])
    }

    @Test
    func emitsEveryLineInOneChunkAndAcceptsCRLF() {
        var buffer = JSONLBuffer()
        let lines = buffer.append(Data("one\ntwo\r\n\n".utf8))
        #expect(lines.map { String(decoding: $0, as: UTF8.self) } == ["one", "two"])
    }
}
