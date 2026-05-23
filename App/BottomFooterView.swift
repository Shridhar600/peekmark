import SwiftUI

struct BottomFooterView: View {
    let url: URL
    @Binding var selectedFontSize: Double
    
    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "folder")
                    .foregroundColor(.secondary)
                    .font(.system(size: 11))
                
                BreadcrumbView(url: url)
            }
            .layoutPriority(0)
            
            Spacer()
            
            // Slider to increase/decrease font size
            HStack(spacing: 8) {
                Image(systemName: "textformat.size.smaller")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                Slider(value: $selectedFontSize, in: 10...28, step: 1)
                    .controlSize(.small)
                    .frame(width: 120)
                
                Image(systemName: "textformat.size.larger")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .layoutPriority(1)
        }
        .padding(.horizontal, 16)
        .frame(height: 38)
        .frame(maxHeight: 38)
        .lineLimit(1)
        .background(.bar)
    }
}
