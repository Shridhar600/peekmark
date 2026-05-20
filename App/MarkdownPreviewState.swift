import Foundation
import SwiftUI

@MainActor
@Observable
final class MarkdownPreviewState {
    var renderedDocument: RenderedDocument = .empty
    var renderGeneration: Int = 0

    func load(url: URL, appearance: MarkdownAppearance) {
        renderGeneration += 1
        let generation = renderGeneration

        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let document = RenderedDocument.load(from: url, appearance: appearance)
            await MainActor.run {
                guard self.renderGeneration == generation else { return }
                self.renderedDocument = document
            }
        }
    }

    func clear() {
        renderedDocument = .empty
        renderGeneration += 1
    }

    func reloadForAppearance(_ appearance: MarkdownAppearance, currentURL: URL?) {
        renderGeneration += 1
        if currentURL == nil {
            renderedDocument = renderedDocument.withAppearance(appearance)
        }
    }
}