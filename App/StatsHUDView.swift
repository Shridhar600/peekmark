import SwiftUI

struct StatsHUDBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 16.0, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: 12))
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct StatsHUDView: View {
    let state: MarkdownPreviewState
    
    @State private var isMetadataExpanded = false
    @State private var showAllMetadata = false
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    private var lastModifiedString: String {
        guard let date = state.renderedDocument.modificationDate else { return "--" }
        return Self.dateFormatter.string(from: date)
    }
    
    var body: some View {
        if !state.renderedDocument.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .foregroundColor(.secondary)
                        .font(.footnote)
                    Text("Document Stats")
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.semibold)
                }
                .padding(.bottom, 2)
                
                HStack {
                    Text("Words:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(state.wordCount)")
                        .fontWeight(.medium)
                }
                .font(.system(.footnote, design: .rounded))
                
                HStack {
                    Text("Characters:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(state.characterCount)")
                        .fontWeight(.medium)
                }
                .font(.system(.footnote, design: .rounded))
                
                HStack {
                    Text("Last Modified:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(lastModifiedString)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }
                .font(.system(.footnote, design: .rounded))
                
                if !state.renderedDocument.metadata.isEmpty {
                    Divider()
                        .padding(.vertical, 4)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        MetadataToggleButton(isExpanded: $isMetadataExpanded)
                        
                        if isMetadataExpanded {
                            VStack(spacing: 6) {
                                let sortedKeys = state.renderedDocument.metadata.keys.sorted()
                                let showAll = self.showAllMetadata || sortedKeys.count <= 4
                                let visibleKeys = showAll ? sortedKeys : Array(sortedKeys.prefix(4))
                                
                                ForEach(visibleKeys, id: \.self) { key in
                                    HStack(alignment: .top) {
                                        Text(key)
                                            .foregroundColor(.secondary)
                                            .lineLimit(2)
                                        Spacer()
                                        Text(state.renderedDocument.metadata[key] ?? "")
                                            .fontWeight(.medium)
                                            .multilineTextAlignment(.trailing)
                                            .lineLimit(3)
                                    }
                                    .font(.system(.footnote, design: .rounded))
                                }
                                
                                if sortedKeys.count > 4 {
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            showAllMetadata.toggle()
                                        }
                                    }) {
                                        Text(showAllMetadata ? "Show Less" : "Show \(sortedKeys.count - 4) More…")
                                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                                            .foregroundColor(.accentColor)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.top, 2)
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                }
            }
            .padding(12)
            .modifier(StatsHUDBackgroundModifier())
            .padding()
        }
    }
}

struct MetadataToggleButton: View {
    @Binding var isExpanded: Bool
    @State private var isHovered = false
    
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        }) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.secondary)
                    .font(.footnote)
                Text("Metadata")
                    .font(.system(.footnote, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(MetadataButtonStyle(isHovered: isHovered))
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

struct MetadataButtonStyle: ButtonStyle {
    let isHovered: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(configuration.isPressed ? Color.secondary.opacity(0.16) : (isHovered ? Color.secondary.opacity(0.08) : Color.clear))
            }
            .scaleEffect(configuration.isPressed ? 0.99 : 1.0)
    }
}
