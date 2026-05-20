import Foundation

enum PostStatus: String, Codable, Hashable {
    case post
    case draft
}

struct Post: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var filename: String
    var filepath: String
    var markdownContent: String
    var frontMatter: String
    var templateId: UUID?
    var status: PostStatus = .post
    var previewUrl: String
}
