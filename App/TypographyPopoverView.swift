import SwiftUI

struct TypographyPopoverView: View {
    @Binding var selectedFont: PreviewFont
    @Binding var selectedSpacing: PreviewSpacing
    @Binding var selectedFontSize: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Typography & Style")
                .font(.system(.headline, design: .rounded))
                .padding(.bottom, 2)
            
            HStack {
                Text("Font Family")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.secondary)
                Spacer()
                Picker("Font Family", selection: $selectedFont) {
                    ForEach(PreviewFont.allCases) { font in
                        Text(font.displayName).tag(font)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            
            HStack {
                Text("Spacing Density")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.secondary)
                Spacer()
                Picker("Spacing Density", selection: $selectedSpacing) {
                    ForEach(PreviewSpacing.allCases) { spacing in
                        Text(spacing.displayName).tag(spacing)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            
            Divider()
                .padding(.vertical, 2)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Font Size")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(selectedFontSize)) px")
                        .font(.system(.subheadline, design: .rounded))
                        .monospacedDigit()
                }
                
                HStack(spacing: 8) {
                    Image(systemName: "textformat.size.smaller")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    Slider(value: $selectedFontSize, in: 10...28, step: 1)
                        .controlSize(.small)
                    
                    Image(systemName: "textformat.size.larger")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .frame(width: 285)
    }
}
