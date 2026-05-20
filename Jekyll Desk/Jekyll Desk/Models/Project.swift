import Foundation

struct Project: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var path: String
    var postsPath: String = "_posts"
    var draftsPath: String = "_drafts"
    var assetsPath: String = "assets"
    var serveCommand: String = "bundle exec jekyll serve"
    var autoStartServerOnPostCreate: Bool = false
    var templates: [FrontMatterTemplate] = FrontMatterTemplate.defaults
    var defaultTemplateID: UUID? = FrontMatterTemplate.defaultPost.id

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case path
        case postsPath
        case draftsPath
        case assetsPath
        case serveCommand
        case autoStartServerOnPostCreate
        case templates
        case defaultTemplateID
    }

    init(
        id: UUID = UUID(),
        name: String,
        path: String,
        postsPath: String = "_posts",
        draftsPath: String = "_drafts",
        assetsPath: String = "assets",
        serveCommand: String = "bundle exec jekyll serve",
        autoStartServerOnPostCreate: Bool = false,
        templates: [FrontMatterTemplate] = FrontMatterTemplate.defaults,
        defaultTemplateID: UUID? = FrontMatterTemplate.defaultPost.id
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.postsPath = postsPath
        self.draftsPath = draftsPath
        self.assetsPath = assetsPath
        self.serveCommand = serveCommand
        self.autoStartServerOnPostCreate = autoStartServerOnPostCreate
        self.templates = templates
        self.defaultTemplateID = defaultTemplateID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        path = try container.decode(String.self, forKey: .path)
        postsPath = try container.decodeIfPresent(String.self, forKey: .postsPath) ?? "_posts"
        draftsPath = try container.decodeIfPresent(String.self, forKey: .draftsPath) ?? "_drafts"
        assetsPath = try container.decodeIfPresent(String.self, forKey: .assetsPath) ?? "assets"
        serveCommand = try container.decodeIfPresent(String.self, forKey: .serveCommand) ?? "bundle exec jekyll serve"
        autoStartServerOnPostCreate = try container.decodeIfPresent(Bool.self, forKey: .autoStartServerOnPostCreate) ?? false
        templates = try container.decodeIfPresent([FrontMatterTemplate].self, forKey: .templates) ?? FrontMatterTemplate.defaults
        defaultTemplateID = try container.decodeIfPresent(UUID.self, forKey: .defaultTemplateID)
    }

    var displayPath: String {
        path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }

    var postsURL: URL {
        URL(fileURLWithPath: path).appendingPathComponent(postsPath)
    }

    var draftsURL: URL {
        URL(fileURLWithPath: path).appendingPathComponent(draftsPath)
    }

    var previewBaseURL: String {
        "http://127.0.0.1:4000"
    }

    var defaultTemplate: FrontMatterTemplate? {
        guard let defaultTemplateID else { return templates.first }
        return templates.first { $0.id == defaultTemplateID } ?? templates.first
    }
}
