import Foundation

enum MarkdownDocumentLoader {
    static let defaultByteLimit = 8 * 1024 * 1024

    static func withSecurityScopedAccess<T>(to url: URL, perform work: (URL) throws -> T) rethrows -> T {
        let resolvedURL = BookmarkManager.resolveBookmark(for: url) ?? url
        let hasScopedAccess = resolvedURL.startAccessingSecurityScopedResource()
        defer {
            if hasScopedAccess {
                resolvedURL.stopAccessingSecurityScopedResource()
            }
        }
        return try work(resolvedURL)
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

enum BookmarkManager {
    private static let key = "secureBookmarks"

    static func saveBookmark(for url: URL) {
        guard url.isFileURL else { return }
        do {
            let isAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if isAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            let bookmarkData = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            var bookmarks = UserDefaults.standard.dictionary(forKey: key) as? [String: Data] ?? [:]
            bookmarks[url.path] = bookmarkData
            UserDefaults.standard.set(bookmarks, forKey: key)
        } catch {
            print("Failed to save bookmark for \(url.path): \(error)")
        }
    }

    static func resolveBookmark(for url: URL) -> URL? {
        guard url.isFileURL else { return nil }
        guard let bookmarks = UserDefaults.standard.dictionary(forKey: key) as? [String: Data],
              let bookmarkData = bookmarks[url.path] else {
            return nil
        }
        do {
            var isStale = false
            let resolvedURL = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            if isStale {
                saveBookmark(for: resolvedURL)
            }
            return resolvedURL
        } catch {
            print("Failed to resolve bookmark for \(url.path): \(error)")
            return nil
        }
    }
}
