import Foundation
import Markdown

public struct HeadingItem: Identifiable, Hashable, Sendable {
    public let id = UUID()
    public let level: Int
    public let title: String
    
    public init(level: Int, title: String) {
        self.level = level
        self.title = title
    }
}

public struct HeadingExtractor {
    public static func extract(from document: Document) -> [HeadingItem] {
        var visitor = HeadingVisitor()
        visitor.visit(document)
        return visitor.headings
    }

    public static func extract(from markdown: String) -> [HeadingItem] {
        let document = Document(parsing: markdown)
        return extract(from: document)
    }
}

private struct HeadingVisitor: MarkupWalker {
    var headings: [HeadingItem] = []
    
    mutating func visitHeading(_ heading: Heading) {
        var textVisitor = PlainTextVisitor()
        textVisitor.visit(heading)
        let title = textVisitor.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty {
            headings.append(HeadingItem(level: heading.level, title: title))
        }
    }
}

private struct PlainTextVisitor: MarkupWalker {
    var text = ""
    
    mutating func visitText(_ text: Text) {
        self.text += text.string
    }
    
    mutating func visitInlineCode(_ inlineCode: InlineCode) {
        self.text += inlineCode.code
    }
    
    mutating func defaultVisit(_ markup: Markup) {
        for child in markup.children {
            descendInto(child)
        }
    }
}
