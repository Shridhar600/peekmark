import SwiftUI

struct SidebarView: View {
    @Binding var openedFile: URL?
    @Binding var sessionRecentFiles: [URL]
    @Binding var recentFilesRaw: String
    let state: MarkdownPreviewState
    
    var body: some View {
        List(selection: $openedFile) {
            let recents = sessionRecentFiles
            Section(header:
                HStack {
                    Text("Recent Documents")
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.semibold)
                    Spacer()
                    Button(action: {
                        recentFilesRaw = ""
                        sessionRecentFiles = []
                        openedFile = nil
                    }) {
                        Text("Clear")
                    }
                    .buttonStyle(ClearButtonStyle())
                    .disabled(recents.isEmpty)
                }
                .padding(.trailing, 16)
                .padding(.bottom, 6)
                .padding(.top, 4)
            ) {
                if recents.isEmpty {
                    Text("No recent documents")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 4)
                } else {
                    ForEach(recents, id: \.self) { url in
                        HStack {
                            Label(url.deletingPathExtension().lastPathComponent, systemImage: "doc.text")
                                .font(.system(.body, design: .rounded))
                                .lineLimit(1)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .tag(url as URL?)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("PeekMark")
        .safeAreaInset(edge: .bottom) {
            StatsHUDView(state: state)
        }
    }
}

struct ClearButtonStyle: ButtonStyle {
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundColor(isHovered ? .primary : .secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2.5)
            .background {
                Capsule()
                    .fill(isHovered ? Color.secondary.opacity(0.15) : Color.secondary.opacity(0.08))
            }
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.15), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}
