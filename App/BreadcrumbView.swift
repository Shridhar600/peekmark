import SwiftUI

struct BreadcrumbView: View {
    let url: URL
    
    var body: some View {
        let components = url.resolvingSymlinksInPath().pathComponents.filter { $0 != "/" && !$0.isEmpty }
        let displayComponents = components.count > 3 ? ["…"] + components.suffix(3) : components
        
        HStack(spacing: 4) {
            ForEach(0..<displayComponents.count, id: \.self) { index in
                let component = displayComponents[index]
                let isLast = index == displayComponents.count - 1
                
                Text(component)
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(isLast ? .primary : .secondary)
                
                if !isLast {
                    Text("›")
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.6))
                }
            }
        }
        .lineLimit(1)
        .truncationMode(.middle)
    }
}
