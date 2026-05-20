import Foundation

enum MarkdownDocumentLoader {
    static let defaultByteLimit = 8 * 1024 * 1024

    static func withSecurityScopedAccess<T>(to url: URL, perform work: () throws -> T) rethrows -> T {
        let hasScopedAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasScopedAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try work()
    }

    static func load(url: URL, byteLimit: Int = defaultByteLimit) throws -> String {
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        if values.isRegularFile == false {
            throw PeekMarkError.notARegularFile
        }
        if let size = values.fileSize, size > byteLimit {
            throw PeekMarkError.fileTooLarge(limit: byteLimit)
        }
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        guard data.count <= byteLimit else {
            throw PeekMarkError.fileTooLarge(limit: byteLimit)
        }
        guard let text = String(data: data, encoding: .utf8) else {
            throw PeekMarkError.unsupportedEncoding
        }
        return text
    }

    static func load(url: URL, byteLimit: Int = defaultByteLimit) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            Task {
                do {
                    let result = try load(url: url, byteLimit: byteLimit)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

enum PeekMarkError: Error, LocalizedError {
    case notARegularFile
    case fileTooLarge(limit: Int)
    case unsupportedEncoding
    case htmlEncodingFailed

    var errorDescription: String? {
        switch self {
        case .notARegularFile:
            return "PeekMark can only preview regular Markdown files."
        case let .fileTooLarge(limit):
            return "This file is larger than PeekMark's \(limit / 1024 / 1024) MB preview limit."
        case .unsupportedEncoding:
            return "This file is not valid UTF-8 text."
        case .htmlEncodingFailed:
            return "PeekMark could not encode the rendered preview."
        }
    }
}
