import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class PeekMarkAppDelegate: NSObject, NSApplicationDelegate {
    private var openDocument: ((URL) -> Void)?
    private var pendingOpenURLs: [URL] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        urls.forEach(open)
    }

    private func open(_ url: URL) {
        guard let openDocument else {
            pendingOpenURLs.append(url)
            return
        }
        openDocument(url)
    }

    func setOpenDocumentHandler(_ handler: @escaping (URL) -> Void) {
        openDocument = handler
        pendingOpenURLs.forEach(handler)
        pendingOpenURLs.removeAll()
    }
}

@main
struct PeekMarkApp: App {
    @NSApplicationDelegateAdaptor(PeekMarkAppDelegate.self) private var appDelegate
    @State private var openedFile: URL?

    var body: some Scene {
        WindowGroup {
            ContentView(openedFile: $openedFile, openMarkdownFile: openMarkdownFile)
                .containerBackground(.windowBackground, for: .window)
                .onAppear {
                    appDelegate.setOpenDocumentHandler { url in
                        BookmarkManager.saveBookmark(for: url)
                        openedFile = url
                    }
                }
                .onOpenURL { url in
                    BookmarkManager.saveBookmark(for: url)
                    openedFile = url
                }
        }
        .windowBackgroundDragBehavior(.enabled)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }

    private func openMarkdownFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            UTType(filenameExtension: "md") ?? .plainText,
            UTType(filenameExtension: "markdown") ?? .plainText
        ]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.begin { response in
            Task { @MainActor in
                guard response == .OK, let url = panel.url else {
                    return
                }
                BookmarkManager.saveBookmark(for: url)
                openedFile = url
            }
        }
    }
}
