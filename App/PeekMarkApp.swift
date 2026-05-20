import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class PeekMarkAppDelegate: NSObject, NSApplicationDelegate {
    private var openDocument: ((URL) -> Void)?
    private var pendingOpenURLs: [URL] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let icon = NSImage(named: "AppIcon") {
            NSApplication.shared.applicationIconImage = icon
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        urls.forEach(open)
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        open(URL(fileURLWithPath: filename))
        return true
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
            ContentView(openedFile: $openedFile, openDocument: openMarkdownFile)
                .onAppear {
                    appDelegate.setOpenDocumentHandler { url in
                        openedFile = url
                    }
                }
                .onOpenURL { url in
                    openedFile = url
                }
        }
        .windowToolbarStyle(.unified(showsTitle: false))
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandGroup(after: .newItem) {
                Button("Open Markdown...") {
                    openMarkdownFile()
                }
                .keyboardShortcut("o")
            }
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
            guard response == .OK, let url = panel.url else {
                return
            }
            openedFile = url
        }
    }
}
