import Foundation

enum SlugService {
    static func slugify(_ value: String) -> String {
        let folded = value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let allowed = CharacterSet.alphanumerics
        let parts = folded.unicodeScalars.map { scalar -> Character in
            allowed.contains(scalar) ? Character(String(scalar).lowercased()) : "-"
        }
        return String(parts)
            .replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}
