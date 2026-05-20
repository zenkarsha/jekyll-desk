import SwiftUI
import AppKit

struct SyntaxMarkdownTextView: NSViewRepresentable {
    @Binding var text: String
    var wordWrap: Bool
    var fontSize: CGFloat
    var tabSize: Int
    var onChange: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = MarkdownScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = !wordWrap

        let textView = MarkdownTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.allowsUndo = true
        textView.drawsBackground = true
        textView.backgroundColor = .white
        textView.textContainerInset = NSSize(width: 16, height: 12)
        textView.textContainer?.lineFragmentPadding = 0
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        applyEditorSettings(to: textView, in: scrollView)

        scrollView.documentView = textView
        scrollView.onLayout = { [weak textView, weak scrollView] in
            guard let textView, let scrollView else { return }
            context.coordinator.parent.applyEditorSettings(to: textView, in: scrollView)
        }
        context.coordinator.applyHighlighting(to: textView, text: text)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        context.coordinator.parent = self
        applyEditorSettings(to: textView, in: scrollView)
        if textView.string != text || context.coordinator.appliedFontSize != fontSize || context.coordinator.appliedTabSize != tabSize {
            context.coordinator.applyHighlighting(to: textView, text: text)
        }
    }

    private func applyEditorSettings(to textView: NSTextView, in scrollView: NSScrollView) {
        applyWordWrap(wordWrap, to: textView, in: scrollView)
        if let markdownTextView = textView as? MarkdownTextView {
            markdownTextView.tabSize = tabSize
        }
        textView.defaultParagraphStyle = paragraphStyle(font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular))
    }

    private func applyWordWrap(_ enabled: Bool, to textView: NSTextView, in scrollView: NSScrollView) {
        guard let textContainer = textView.textContainer else { return }
        scrollView.hasHorizontalScroller = !enabled
        textContainer.widthTracksTextView = enabled
        textView.isHorizontallyResizable = !enabled
        textView.autoresizingMask = enabled ? [.width] : []

        if enabled {
            let wrapWidth = max(1, scrollView.contentSize.width - (textView.textContainerInset.width * 2) - 2)
            textView.frame.size.width = scrollView.contentSize.width
            textContainer.containerSize = NSSize(
                width: wrapWidth,
                height: CGFloat.greatestFiniteMagnitude
            )
            textView.maxSize = NSSize(
                width: scrollView.contentSize.width,
                height: CGFloat.greatestFiniteMagnitude
            )
        } else {
            textContainer.containerSize = NSSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )
            textView.frame.size.width = max(scrollView.contentSize.width, textView.intrinsicContentSize.width)
            textView.maxSize = NSSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )
        }
        textContainer.size = textContainer.containerSize
        textView.layoutManager?.ensureLayout(for: textContainer)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SyntaxMarkdownTextView
        var appliedFontSize: CGFloat = 0
        var appliedTabSize: Int = 0
        private var isApplying = false

        init(_ parent: SyntaxMarkdownTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard !isApplying, let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            parent.onChange(textView.string)
            applyHighlighting(to: textView, text: textView.string)
        }

        func applyHighlighting(to textView: NSTextView, text: String) {
            isApplying = true
            let selectedRanges = textView.selectedRanges
            let attributed = NSMutableAttributedString(string: text)
            let fullRange = NSRange(location: 0, length: attributed.length)
            let font = NSFont.monospacedSystemFont(ofSize: parent.fontSize, weight: .regular)
            attributed.addAttributes([
                .font: font,
                .foregroundColor: NSColor(red: 0.07, green: 0.09, blue: 0.15, alpha: 1),
                .paragraphStyle: parent.paragraphStyle(font: font)
            ], range: fullRange)

            apply(pattern: #"^---$"#, color: .black, text: text, attributed: attributed)
            apply(pattern: #"(?m)^([a-zA-Z_]+):"#, color: NSColor.systemGreen, text: text, attributed: attributed)
            apply(pattern: #""[^"]*""#, color: NSColor.systemRed, text: text, attributed: attributed)
            apply(pattern: #"(?m)^\s+-\s+(.+)$"#, color: NSColor.systemRed, text: text, attributed: attributed)
            apply(pattern: #"(?m)^#{1,3}\s+.*$"#, color: NSColor.systemBlue, text: text, attributed: attributed)

            textView.textStorage?.setAttributedString(attributed)
            textView.selectedRanges = selectedRanges.map {
                let range = $0.rangeValue
                let location = min(range.location, attributed.length)
                let length = min(range.length, max(0, attributed.length - location))
                return NSValue(range: NSRange(location: location, length: length))
            }
            appliedFontSize = parent.fontSize
            appliedTabSize = parent.tabSize
            isApplying = false
        }

        private func apply(pattern: String, color: NSColor, text: String, attributed: NSMutableAttributedString) {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            regex.matches(in: text, range: range).forEach { match in
                attributed.addAttribute(.foregroundColor, value: color, range: match.range)
            }
        }
    }

    private func paragraphStyle(font: NSFont) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        let spaceWidth = (" " as NSString).size(withAttributes: [.font: font]).width
        let tabWidth = spaceWidth * CGFloat(tabSize)
        style.lineSpacing = 5
        style.defaultTabInterval = tabWidth
        style.tabStops = stride(from: tabWidth, through: tabWidth * 40, by: tabWidth).map {
            NSTextTab(textAlignment: .left, location: $0)
        }
        return style
    }
}

private final class MarkdownScrollView: NSScrollView {
    var onLayout: (() -> Void)?

    override func layout() {
        super.layout()
        onLayout?()
    }
}

private final class MarkdownTextView: NSTextView {
    var tabSize = 2

    override func insertTab(_ sender: Any?) {
        insertText(String(repeating: " ", count: tabSize), replacementRange: selectedRange())
    }
}
