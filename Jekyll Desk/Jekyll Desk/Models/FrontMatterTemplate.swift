import Foundation

struct FrontMatterTemplate: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var slug: String
    var yamlTemplate: String
    var fields: [FrontMatterField]

    static let defaultPost = FrontMatterTemplate(
        id: UUID(uuidString: "8A91A12F-72D7-4F1F-B2D0-B8D20A90D6A8")!,
        name: "Blog Post",
        slug: "blog-post",
        yamlTemplate: """
        ---
        layout: post
        title: {TITLE}
        date: {DATETIME}
        category: {CATEGORY}
        tags:
          - {TAG}
        description: {DESCRIPTION}
        ---
        """,
        fields: [
            .init(placeholder: "TITLE", label: "Title", type: .text, required: true, repeatable: false),
            .init(placeholder: "DATETIME", label: "Date", type: .date, required: true, repeatable: false),
            .init(placeholder: "CATEGORY", label: "Category", type: .text, required: false, repeatable: false),
            .init(placeholder: "TAG", label: "Tags", type: .tagList, required: false, repeatable: true),
            .init(placeholder: "DESCRIPTION", label: "Description", type: .text, required: false, repeatable: false)
        ]
    )

    static let defaults: [FrontMatterTemplate] = [.defaultPost]

    var isLegacySample: Bool {
        slug == "single-video" || slug == "multiple-videos"
    }
}
