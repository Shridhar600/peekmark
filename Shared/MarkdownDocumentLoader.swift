import Foundation
import os

private let logger = Logger(subsystem: "app.peekmark", category: "BookmarkManager")

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
        
        let originalAccessed = url.startAccessingSecurityScopedResource()
        defer {
            if originalAccessed {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        let targetURL = url.standardizedFileURL.resolvingSymlinksInPath()
        let targetAccessed = targetURL.startAccessingSecurityScopedResource()
        defer {
            if targetAccessed {
                targetURL.stopAccessingSecurityScopedResource()
            }
        }
        
        let resolvedPath = targetURL.path
        do {
            let bookmarkData = try targetURL.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            var bookmarks = UserDefaults.standard.dictionary(forKey: key) as? [String: Data] ?? [:]
            bookmarks[resolvedPath] = bookmarkData
            UserDefaults.standard.set(bookmarks, forKey: key)
        } catch {
            logger.error("Failed to save bookmark for \(resolvedPath, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    static func resolveBookmark(for url: URL) -> URL? {
        guard url.isFileURL else { return nil }
        let targetURL = url.standardizedFileURL.resolvingSymlinksInPath()
        let resolvedPath = targetURL.path
        guard let bookmarks = UserDefaults.standard.dictionary(forKey: key) as? [String: Data],
              let bookmarkData = bookmarks[resolvedPath] else {
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
            logger.error("Failed to resolve bookmark for \(resolvedPath, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
