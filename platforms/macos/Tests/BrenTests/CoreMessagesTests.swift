import Foundation
import Testing
@testable import Bren

struct CoreMessagesTests {
    @Test
    func decodesDeltaEvent() throws {
        let data = Data(#"{"v":1,"id":"request-1","event":"delta","data":{"text":"你好"}}"#.utf8)
        let event = try JSONDecoder().decode(CoreEvent.self, from: data)
        #expect(event.v == 1)
        #expect(event.id == "request-1")
        #expect(event.event == "delta")
        #expect(event.data?.text == "你好")
    }

    @Test
    func decodesErrorEvent() throws {
        let data = Data(#"{"v":1,"id":"request-1","event":"error","error":{"code":"backend_error","message":"offline","retryable":true}}"#.utf8)
        let event = try JSONDecoder().decode(CoreEvent.self, from: data)
        #expect(event.error?.code == "backend_error")
        #expect(event.error?.message == "offline")
        #expect(event.error?.retryable == true)
    }
}
