import Foundation

enum CoreLocator {
    static func executableURL(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        bundle: Bundle = .main
    ) throws -> URL {
        if let explicitPath = environment["BREN_CORE_PATH"], !explicitPath.isEmpty {
            let url = URL(fileURLWithPath: explicitPath)
            guard FileManager.default.isExecutableFile(atPath: url.path) else {
                throw CoreLocationError.notExecutable(url.path)
            }
            return url
        }

        let bundledURL = bundle.bundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Helpers", isDirectory: true)
            .appendingPathComponent("bren-core", isDirectory: false)
        guard FileManager.default.isExecutableFile(atPath: bundledURL.path) else {
            throw CoreLocationError.notFound
        }
        return bundledURL
    }
}

enum CoreLocationError: LocalizedError {
    case notFound
    case notExecutable(String)

    var errorDescription: String? {
        switch self {
        case .notFound:
            "找不到 bren-core。请使用构建脚本生成完整的 Bren.app。"
        case let .notExecutable(path):
            "bren-core 不可执行：\(path)"
        }
    }
}
