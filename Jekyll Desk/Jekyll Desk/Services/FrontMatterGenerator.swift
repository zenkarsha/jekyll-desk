import Foundation

enum FrontMatterGenerator {
    static func generate(template: FrontMatterTemplate, values: [String: [String]]) -> String {
        let lines = template.yamlTemplate.components(separatedBy: .newlines)
        var output: [String] = []

        for line in lines {
            guard let placeholder = placeholder(in: line) else {
                output.append(replacingScalars(in: line, values: values))
                continue
            }

            let field = template.fields.first { $0.placeholder == placeholder }
            let fieldValues = cleaned(values[placeholder] ?? [])

            if field?.repeatable == true && line.trimmingCharacters(in: .whitespaces).hasPrefix("-") {
                let indent = String(line.prefix { $0 == " " || $0 == "\t" })
                if fieldValues.isEmpty {
                    output.append("\(indent)- ")
                } else {
                    output.append(contentsOf: fieldValues.map { "\(indent)- \(yamlScalar($0))" })
                }
            } else {
                output.append(replacingScalars(in: line, values: values))
            }
        }

        return output.joined(separator: "\n")
    }

    static func upsert(frontMatter: String, into markdown: String) -> String {
        if let block = FrontMatterParser.frontMatterBlock(in: markdown) {
            var updated = markdown
            updated.replaceSubrange(block, with: frontMatter)
            return updated
        }

        return frontMatter + "\n\n" + markdown
    }

    private static func replacingScalars(in line: String, values: [String: [String]]) -> String {
        var result = line
        for (placeholder, rawValues) in values {
            let value = cleaned(rawValues).first ?? ""
            let scalar = line.trimmingCharacters(in: .whitespaces).hasPrefix("key:")
                ? SlugService.slugify(value)
                : yamlScalar(value)
            result = result.replacingOccurrences(of: "{\(placeholder)}", with: scalar)
        }
        return result
    }

    private static func placeholder(in line: String) -> String? {
        guard let start = line.range(of: "{"), let end = line.range(of: "}", range: start.upperBound..<line.endIndex) else {
            return nil
        }
        return String(line[start.upperBound..<end.lowerBound])
    }

    private static func cleaned(_ values: [String]) -> [String] {
        values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    private static func yamlScalar(_ value: String) -> String {
        if value.isEmpty { return "\"\"" }
        let needsQuotes = value.contains(" ") || value.contains(":") || value.contains("#") || value.hasPrefix("{") || value.hasPrefix("[")
        return needsQuotes ? "\"\(value.replacingOccurrences(of: "\"", with: "\\\""))\"" : value
    }
}
