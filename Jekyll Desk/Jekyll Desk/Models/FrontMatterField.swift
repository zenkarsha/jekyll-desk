import Foundation

enum FrontMatterFieldType: String, Codable, CaseIterable, Hashable {
    case text
    case date
    case select
    case tagList = "tag-list"
    case repeatableText = "repeatable-text"
    case boolean

    var displayName: String {
        switch self {
        case .text: "text"
        case .date: "date"
        case .select: "select"
        case .tagList: "tag list"
        case .repeatableText: "repeatable text"
        case .boolean: "boolean"
        }
    }
}

struct FrontMatterField: Identifiable, Codable, Hashable {
    var id: String { placeholder }
    var placeholder: String
    var label: String
    var type: FrontMatterFieldType
    var required: Bool
    var repeatable: Bool
    var defaultValue: String = ""
    var options: [String] = []
}
