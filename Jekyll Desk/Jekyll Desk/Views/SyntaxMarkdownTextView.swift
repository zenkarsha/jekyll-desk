import SwiftUI
import AppKit

struct SyntaxMarkdownTextView: NSViewRepresentable {
    @Binding var text: String
    var project: Project?
    var postFilename: String
    var postTitle: String
    var postDate: String
    var wordWrap: Bool
    var showsLineNumbers: Bool
    var fontSize: CGFloat
    var tabSize: Int
    var onChange: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = MarkdownScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
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
        textView.textContainer?.lineFragmentPadding = 0
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.registerForDraggedTypes([.fileURL])
        textView.imageDropHandler = { [weak coordinator = context.coordinator] textView, sender in
            coordinator?.handleImageDrop(in: textView, sender: sender) ?? false
        }

        scrollView.documentView = textView
        configureLineNumberRuler(for: scrollView, textView: textView)
        applyEditorSettings(to: textView, in: scrollView)
        scrollView.onLayout = { [weak textView, weak scrollView] in
            guard let textView, let scrollView else { return }
            context.coordinator.parent.applyEditorSettings(to: textView, in: scrollView)
            context.coordinator.parent.invalidateLineNumberRuler(in: scrollView)
        }
        context.coordinator.applyHighlighting(to: textView, text: text)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        context.coordinator.parent = self
        if let markdownTextView = textView as? MarkdownTextView {
            markdownTextView.imageDropHandler = { [weak coordinator = context.coordinator] textView, sender in
                coordinator?.handleImageDrop(in: textView, sender: sender) ?? false
            }
        }
        configureLineNumberRuler(for: scrollView, textView: textView)
        applyEditorSettings(to: textView, in: scrollView)
        if textView.string != text || context.coordinator.appliedFontSize != fontSize || context.coordinator.appliedTabSize != tabSize {
            context.coordinator.applyHighlighting(to: textView, text: text)
        }
        invalidateLineNumberRuler(in: scrollView)
    }

    private func applyEditorSettings(to textView: NSTextView, in scrollView: NSScrollView) {
        if let markdownTextView = textView as? MarkdownTextView {
            markdownTextView.tabSize = tabSize
        }
        textView.textContainerInset = NSSize(width: 16, height: 12)
        textView.defaultParagraphStyle = paragraphStyle(font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular))
        applyWordWrap(wordWrap, to: textView, in: scrollView)
    }

    private func applyWordWrap(_ enabled: Bool, to textView: NSTextView, in scrollView: NSScrollView) {
        guard let textContainer = textView.textContainer else { return }
        scrollView.hasHorizontalScroller = !enabled
        textContainer.widthTracksTextView = enabled
        textView.isHorizontallyResizable = !enabled
        textView.autoresizingMask = enabled ? [.width] : []

        if enabled {
            let editorWidth = availableEditorWidth(in: scrollView)
            let wrapWidth = max(1, editorWidth - (textView.textContainerInset.width * 2))
            textView.frame.size.width = editorWidth
            textContainer.containerSize = NSSize(
                width: wrapWidth,
                height: CGFloat.greatestFiniteMagnitude
            )
            textView.maxSize = NSSize(
                width: editorWidth,
                height: CGFloat.greatestFiniteMagnitude
            )
        } else {
            let editorWidth = availableEditorWidth(in: scrollView)
            textContainer.containerSize = NSSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )
            textView.frame.size.width = max(editorWidth, textView.intrinsicContentSize.width)
            textView.maxSize = NSSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )
        }
        textContainer.size = textContainer.containerSize
        textView.layoutManager?.ensureLayout(for: textContainer)
        textView.needsDisplay = true
    }

    private func availableEditorWidth(in scrollView: NSScrollView) -> CGFloat {
        var width = scrollView.contentView.bounds.width

        if
            showsLineNumbers,
            scrollView.hasVerticalRuler,
            scrollView.rulersVisible,
            let ruler = scrollView.verticalRulerView
        {
            let rulerWidth = ruler.ruleThickness
            let contentStartsAfterRuler = scrollView.contentView.frame.minX >= rulerWidth - 1
            if !contentStartsAfterRuler {
                width -= rulerWidth
            }
        }

        return max(1, width)
    }

    private func configureLineNumberRuler(for scrollView: NSScrollView, textView: NSTextView) {
        scrollView.contentView.postsBoundsChangedNotifications = true
        guard showsLineNumbers else {
            scrollView.hasVerticalRuler = false
            scrollView.rulersVisible = false
            scrollView.verticalRulerView = nil
            return
        }

        let ruler: MarkdownLineNumberRulerView
        if let existingRuler = scrollView.verticalRulerView as? MarkdownLineNumberRulerView {
            ruler = existingRuler
        } else {
            ruler = MarkdownLineNumberRulerView(scrollView: scrollView, orientation: .verticalRuler)
            scrollView.verticalRulerView = ruler
        }

        ruler.clientView = textView
        ruler.textView = textView
        ruler.fontSize = fontSize
        ruler.ruleThickness = 44
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true
        ruler.needsDisplay = true
    }

    private func invalidateLineNumberRuler(in scrollView: NSScrollView) {
        (scrollView.verticalRulerView as? MarkdownLineNumberRulerView)?.needsDisplay = true
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
            textView.enclosingScrollView?.verticalRulerView?.needsDisplay = true
        }

        func handleImageDrop(in textView: NSTextView, sender: NSDraggingInfo) -> Bool {
            guard let project = parent.project else { return false }
            let urls = (sender.draggingPasteboard.readObjects(forClasses: [NSURL.self]) as? [NSURL] ?? [])
                .map { $0 as URL }

            do {
                let imagePaths = try MarkdownFileService.importImages(
                    urls,
                    project: project,
                    postFilename: parent.postFilename,
                    title: parent.postTitle,
                    date: parent.postDate
                )
                guard !imagePaths.isEmpty else { return false }

                let insertionIndex = insertionIndex(for: sender, in: textView)
                let markdown = imagePaths
                    .map { "![alt text](\($0))" }
                    .joined(separator: "\n")
                let prefix = needsLeadingNewline(in: textView.string, insertionIndex: insertionIndex) ? "\n" : ""
                let suffix = needsTrailingNewline(in: textView.string, insertionIndex: insertionIndex) ? "\n" : ""

                textView.insertText(prefix + markdown + suffix, replacementRange: NSRange(location: insertionIndex, length: 0))
                parent.text = textView.string
                parent.onChange(textView.string)
                applyHighlighting(to: textView, text: textView.string)
                return true
            } catch {
                NSSound.beep()
                return false
            }
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
            textView.enclosingScrollView?.verticalRulerView?.needsDisplay = true
        }

        private func apply(pattern: String, color: NSColor, text: String, attributed: NSMutableAttributedString) {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            regex.matches(in: text, range: range).forEach { match in
                attributed.addAttribute(.foregroundColor, value: color, range: match.range)
            }
        }

        private func insertionIndex(for sender: NSDraggingInfo, in textView: NSTextView) -> Int {
            guard let layoutManager = textView.layoutManager, let textContainer = textView.textContainer else {
                return textView.selectedRange().location
            }

            let dropPoint = textView.convert(sender.draggingLocation, from: nil)
            let containerOrigin = textView.textContainerOrigin
            let containerPoint = NSPoint(
                x: dropPoint.x - containerOrigin.x,
                y: dropPoint.y - containerOrigin.y
            )
            let glyphIndex = layoutManager.glyphIndex(for: containerPoint, in: textContainer)
            return min(layoutManager.characterIndexForGlyph(at: glyphIndex), textView.string.utf16.count)
        }

        private func needsLeadingNewline(in text: String, insertionIndex: Int) -> Bool {
            guard insertionIndex > 0 else { return false }
            let nsText = text as NSString
            return nsText.substring(with: NSRange(location: insertionIndex - 1, length: 1)) != "\n"
        }

        private func needsTrailingNewline(in text: String, insertionIndex: Int) -> Bool {
            guard insertionIndex < text.utf16.count else { return false }
            let nsText = text as NSString
            return nsText.substring(with: NSRange(location: insertionIndex, length: 1)) != "\n"
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

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        layer?.masksToBounds = true
        onLayout?()
    }

    override func reflectScrolledClipView(_ clipView: NSClipView) {
        super.reflectScrolledClipView(clipView)
        verticalRulerView?.needsDisplay = true
    }
}

private final class MarkdownLineNumberRulerView: NSRulerView {
    weak var textView: NSTextView?
    var fontSize: CGFloat = 13

    private var rulerBackgroundColor: NSColor {
        NSColor(red: 0.949, green: 0.957, blue: 0.969, alpha: 1)
    }

    private var textColor: NSColor {
        NSColor.secondaryLabelColor
    }

    override var isFlipped: Bool {
        true
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard
            let textView,
            let layoutManager = textView.layoutManager,
            let textContainer = textView.textContainer
        else { return }

        rulerBackgroundColor.setFill()
        bounds.fill()

        layoutManager.ensureLayout(for: textContainer)

        let visibleRect = textView.visibleRect
        let textOrigin = textView.textContainerOrigin
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: max(11, fontSize - 1), weight: .regular),
            .foregroundColor: textColor
        ]
        let lineStarts = lineStartIndexes(in: textView.string)

        for (index, lineStart) in lineStarts.enumerated() {
            guard let lineY = yPosition(forCharacterAt: lineStart, layoutManager: layoutManager, textView: textView, textContainer: textContainer) else {
                continue
            }

            let y = lineY + textOrigin.y - visibleRect.minY
            if y < rect.minY - 24 || y > rect.maxY + 24 {
                continue
            }

            let label = "\(index + 1)" as NSString
            let labelSize = label.size(withAttributes: attributes)
            let labelRect = NSRect(
                x: bounds.width - labelSize.width - 10,
                y: y + ((lineHeight(for: lineStart, layoutManager: layoutManager) - labelSize.height) / 2),
                width: labelSize.width,
                height: labelSize.height
            )
            label.draw(in: labelRect, withAttributes: attributes)
        }
    }

    private func lineStartIndexes(in text: String) -> [Int] {
        let nsText = text as NSString
        guard nsText.length > 0 else { return [0] }

        var starts = [0]
        var searchLocation = 0
        while searchLocation < nsText.length {
            let range = nsText.range(of: "\n", options: [], range: NSRange(location: searchLocation, length: nsText.length - searchLocation))
            guard range.location != NSNotFound else { break }

            let nextStart = range.location + range.length
            starts.append(nextStart)
            searchLocation = nextStart
        }
        return starts
    }

    private func yPosition(
        forCharacterAt characterIndex: Int,
        layoutManager: NSLayoutManager,
        textView: NSTextView,
        textContainer: NSTextContainer
    ) -> CGFloat? {
        let characterCount = (textView.string as NSString).length
        guard characterCount > 0 else {
            return layoutManager.extraLineFragmentRect.minY
        }

        if characterIndex >= characterCount {
            let extraLineRect = layoutManager.extraLineFragmentRect
            if !extraLineRect.isEmpty {
                return extraLineRect.minY
            }
            return nil
        }

        let glyphIndex = layoutManager.glyphIndexForCharacter(at: characterIndex)
        return layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil).minY
    }

    private func lineHeight(
        for characterIndex: Int,
        layoutManager: NSLayoutManager
    ) -> CGFloat {
        let fallbackHeight = fontSize + 5
        let characterCount = layoutManager.textStorage?.length ?? 0
        if characterIndex >= characterCount {
            let extraLineHeight = layoutManager.extraLineFragmentRect.height
            return extraLineHeight > 0 ? extraLineHeight : fallbackHeight
        }

        guard layoutManager.numberOfGlyphs > 0 else {
            return fallbackHeight
        }

        let glyphIndex = min(layoutManager.numberOfGlyphs - 1, layoutManager.glyphIndexForCharacter(at: characterIndex))
        return layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil).height
    }
}

private final class MarkdownTextView: NSTextView {
    var tabSize = 2
    var imageDropHandler: ((MarkdownTextView, NSDraggingInfo) -> Bool)?

    override func insertTab(_ sender: Any?) {
        insertText(String(repeating: " ", count: tabSize), replacementRange: selectedRange())
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        hasImageURLs(sender) ? .copy : super.draggingEntered(sender)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        hasImageURLs(sender) ? .copy : super.draggingUpdated(sender)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        if hasImageURLs(sender), imageDropHandler?(self, sender) == true {
            return true
        }
        return super.performDragOperation(sender)
    }

    private func hasImageURLs(_ sender: NSDraggingInfo) -> Bool {
        let urls = (sender.draggingPasteboard.readObjects(forClasses: [NSURL.self]) as? [NSURL] ?? [])
            .map { $0 as URL }
        return urls.contains { ["apng", "avif", "gif", "jpeg", "jpg", "png", "svg", "webp"].contains($0.pathExtension.lowercased()) }
    }
}
