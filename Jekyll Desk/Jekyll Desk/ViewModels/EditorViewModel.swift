import Foundation
import Combine

enum EditorLayoutMode {
    case editorOnly
    case editorAndPreview
    case previewOnly
}

@MainActor
final class EditorViewModel: ObservableObject {
    static let defaultWordWrap = true
    static let defaultLineNumbers = true
    static let defaultFontSize = 14
    static let defaultTabSize = 2

    @Published var selectedTemplate: FrontMatterTemplate = .defaultPost
    @Published var formValues: [String: [String]] = [:]
    @Published var markdownContent: String = ""
    @Published var filename: String = "Untitled.md"
    @Published var filepath: String?
    @Published var isSaved = true
    @Published var layoutMode: EditorLayoutMode = .editorAndPreview
    @Published var wordWrap = EditorViewModel.defaultWordWrap
    @Published var lineNumbers = EditorViewModel.defaultLineNumbers
    @Published var fontSize: Int {
        didSet {
            UserDefaults.standard.set(fontSize, forKey: Self.fontSizeDefaultsKey)
        }
    }
    @Published var tabSize: Int {
        didSet {
            UserDefaults.standard.set(tabSize, forKey: Self.tabSizeDefaultsKey)
        }
    }
    @Published var lastSavedURL: URL?
    @Published var focusedField: String?

    private var saveTask: Task<Void, Never>?
    private var frontMatterTask: Task<Void, Never>?

    init() {
        fontSize = Self.clampedFontSize(UserDefaults.standard.integer(forKey: Self.fontSizeDefaultsKey))
        tabSize = Self.clampedTabSize(UserDefaults.standard.integer(forKey: Self.tabSizeDefaultsKey))
    }

    var title: String {
        formValues["TITLE"]?.first?.isEmpty == false ? formValues["TITLE"]!.first! : "Untitled Post"
    }

    var date: String {
        formValues["DATE"]?.first?.isEmpty == false ? formValues["DATE"]!.first! : Self.dateFormatter.string(from: Date())
    }

    var category: String {
        formValues["CATEGORY"]?.first ?? ""
    }

    var videoIDs: [String] {
        formValues["YOUTUBE_VIDEO_ID"] ?? []
    }

    var tags: [String] {
        formValues["TAG"] ?? []
    }

    func selectTemplate(_ template: FrontMatterTemplate) {
        selectedTemplate = template
        ensureValues(for: template)
        if !markdownContent.isEmpty {
            generateAndApplyFrontMatter()
        }
    }

    func updateValue(_ placeholder: String, index: Int = 0, value: String) {
        var values = formValues[placeholder] ?? [""]
        while values.count <= index { values.append("") }
        values[index] = value
        formValues[placeholder] = values
    }

    func addValue(_ placeholder: String, value: String = "") {
        formValues[placeholder, default: []].append(value)
    }

    func removeValue(_ placeholder: String, index: Int) {
        guard var values = formValues[placeholder], values.indices.contains(index) else { return }
        values.remove(at: index)
        if values.isEmpty { values = [""] }
        formValues[placeholder] = values
    }

    func addTag(_ tag: String) {
        let normalized = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        if !tags.contains(normalized) {
            formValues["TAG", default: []].append(normalized)
        }
    }

    func removeTag(_ tag: String) {
        formValues["TAG"] = tags.filter { $0 != tag }
    }

    func validateRequiredFields() -> Bool {
        guard let missingField = selectedTemplate.fields.first(where: { $0.required && !isFilled($0) }) else {
            focusedField = nil
            return true
        }

        focusedField = nil
        Task { @MainActor in
            self.focusedField = missingField.placeholder
        }
        return false
    }

    func generateAndApplyFrontMatter() {
        let frontMatter = FrontMatterGenerator.generate(template: selectedTemplate, values: normalizedValuesForGeneration())
        let body = bodyMarkdown(from: markdownContent)
        let fallback = body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? MarkdownFileService.defaultMarkdown(title: title, multiVideo: selectedTemplate.slug == "multiple-videos")
            : body
        markdownContent = FrontMatterGenerator.upsert(frontMatter: frontMatter, into: fallback)
        filename = MarkdownFileService.filename(date: date, title: title)
        isSaved = false
    }

    @discardableResult
    func save(project: Project?) -> URL? {
        guard let project else { return nil }
        do {
            let url = try MarkdownFileService.save(
                content: markdownContent,
                project: project,
                title: title,
                date: date,
                existingPath: filepath
            )
            filepath = url.path
            filename = url.lastPathComponent
            lastSavedURL = url
            isSaved = true
            return url
        } catch {
            isSaved = false
            return nil
        }
    }

    func scheduleAutosave(project: Project?, onSaved: @escaping (URL) -> Void) {
        isSaved = false
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if let url = self?.save(project: project) {
                    onSaved(url)
                }
            }
        }
    }

    func scheduleFrontMatterUpdate(project: Project?, onSaved: @escaping (URL) -> Void) {
        guard filepath != nil, !markdownContent.isEmpty else { return }
        isSaved = false
        frontMatterTask?.cancel()
        frontMatterTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self else { return }
                self.generateAndApplyFrontMatter()
                if let url = self.save(project: project) {
                    onSaved(url)
                }
            }
        }
    }

    func open(post: Post) {
        filepath = post.filepath
        filename = post.filename
        markdownContent = post.markdownContent
        isSaved = true
    }

    func resetPost(resetForm: Bool = false) {
        saveTask?.cancel()
        frontMatterTask?.cancel()
        filepath = nil
        lastSavedURL = nil
        markdownContent = ""
        filename = "Untitled.md"
        isSaved = true
        if resetForm {
            formValues = [:]
            ensureValues(for: selectedTemplate)
        }
    }

    func updateOpenedFile(to url: URL) {
        filepath = url.path
        filename = url.lastPathComponent
        lastSavedURL = url
        isSaved = true
    }

    func setFontSize(_ size: Int) {
        fontSize = Self.clampedFontSize(size)
    }

    func setTabSize(_ size: Int) {
        tabSize = Self.clampedTabSize(size)
    }

    func resetSettingsToDefault() {
        wordWrap = Self.defaultWordWrap
        lineNumbers = Self.defaultLineNumbers
        fontSize = Self.defaultFontSize
        tabSize = Self.defaultTabSize
    }

    private func normalizedValuesForGeneration() -> [String: [String]] {
        var values = formValues
        values["TITLE"] = [title]
        values["DATE"] = [date]
        if values["DATETIME"]?.first?.isEmpty != false {
            values["DATETIME"] = [Self.dateTimeFormatter.string(from: Date())]
        }
        values["CATEGORY"] = [category]
        return values
    }

    private func ensureValues(for template: FrontMatterTemplate) {
        for field in template.fields where formValues[field.placeholder]?.first?.isEmpty != false {
            switch field.placeholder {
            case "DATE":
                formValues[field.placeholder] = [Self.dateFormatter.string(from: Date())]
            case "DATETIME":
                formValues[field.placeholder] = [Self.dateTimeFormatter.string(from: Date())]
            case "TAG":
                formValues[field.placeholder] = tags.isEmpty ? [""] : tags
            default:
                formValues[field.placeholder] = [field.defaultValue]
            }
        }
    }

    private func isFilled(_ field: FrontMatterField) -> Bool {
        let values = formValues[field.placeholder] ?? []

        switch field.type {
        case .tagList, .repeatableText:
            return values.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        case .boolean:
            return values.first != nil
        case .text, .date, .select:
            return values.first?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        }
    }

    private func bodyMarkdown(from markdown: String) -> String {
        guard let range = FrontMatterParser.frontMatterBlock(in: markdown) else { return markdown }
        return String(markdown[range.upperBound...]).trimmingCharacters(in: .newlines)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        return formatter
    }()

    private static let fontSizeDefaultsKey = "JekyllDesk.editorFontSize"
    private static let tabSizeDefaultsKey = "JekyllDesk.editorTabSize"

    private static func clampedFontSize(_ size: Int) -> Int {
        guard size > 0 else { return defaultFontSize }
        return min(max(size, 12), 16)
    }

    private static func clampedTabSize(_ size: Int) -> Int {
        [2, 4].contains(size) ? size : defaultTabSize
    }
}
