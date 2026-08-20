import Foundation

struct CoreEvent: Decodable {
    let v: Int
    let id: String?
    let event: String
    let data: CoreEventData?
    let error: CoreErrorData?
}

struct CoreEventData: Decodable {
    let backend: String?
    let model: String?
    let version: String?
    let text: String?
    let latencyMs: Int?
    let ok: Bool?
    let cancelled: Bool?
}

struct CoreErrorData: Decodable {
    let code: String
    let message: String
    let retryable: Bool
}

struct CoreRequest<Parameters: Encodable>: Encodable {
    let v = 1
    let id: String
    let method: String
    let params: Parameters
}

struct TranslateRequestParameters: Encodable {
    let text: String
}

struct CancelRequestParameters: Encodable {
    let requestId: String
}
