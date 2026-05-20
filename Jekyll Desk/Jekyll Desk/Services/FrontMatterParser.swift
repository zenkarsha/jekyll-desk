import Foundation

enum FrontMatterParser {
    static func placeholders(in template: String) -> [String] {
        let regex = try? NSRegularExpression(pattern: #"\{([A-Z0-9_]+)\}"#)
        let range = NSRange(template.startIndex..<template.endIndex, in: template)
        let matches = regex?.matches(in: template, range: range) ?? []
        var seen: [String] = []

        for match in matches {
            guard let swiftRange = Range(match.range(at: 1), in: template) else { continue }
            let token = String(template[swiftRange])
            if !seen.contains(token) {
                seen.append(token)
            }
        }

        return seen
    }

    static func isRepeatable(_ placeholder: String, in template: String) -> Bool {
        template
            .components(separatedBy: .newlines)
            .contains { line in
                line.trimmingCharacters(in: .whitespaces).hasPrefix("-") && line.contains("{\(placeholder)}")
            }
    }

    static func fields(from template: String) -> [FrontMatterField] {
        placeholders(in: template).map { placeholder in
            let repeatable = isRepeatable(placeholder, in: template)
            let type: FrontMatterFieldType = {
                if placeholder == "DATE" || placeholder == "DATETIME" { return .date }
                if placeholder == "CATEGORY" { return .text }
                if placeholder == "TAG" { return .tagList }
                if repeatable { return .repeatableText }
                return .text
            }()

            return FrontMatterField(
                placeholder: placeholder,
                label: label(for: placeholder, repeatable: repeatable),
                type: type,
                required: placeholder != "TAG",
                repeatable: repeatable,
                options: []
            )
        }
    }

    static func frontMatterBlock(in markdown: String) -> Range<String.Index>? {
        guard markdown.hasPrefix("---") else { return nil }
        let start = markdown.startIndex
        let searchStart = markdown.index(start, offsetBy: 3)
        guard let endRange = markdown.range(of: "\n---", range: searchStart..<markdown.endIndex) else { return nil }
        let end = markdown.index(endRange.upperBound, offsetBy: 0)
        return start..<end
    }

    private static func label(for placeholder: String, repeatable: Bool) -> String {
        switch placeholder {
        case "TITLE": "Title"
        case "DATE": "Date"
        case "DATETIME": "Date"
        case "CATEGORY": "Category"
        case "DESCRIPTION": "Description"
        case "YOUTUBE_VIDEO_ID": repeatable ? "YouTube Video IDs" : "YouTube Video ID"
        case "TAG": "Tags"
        default: placeholder.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}
