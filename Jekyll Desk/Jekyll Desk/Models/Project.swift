import Foundation

struct Project: Identifiable, Codable, Hashable {
    static let defaultPostsPath = "_posts"
    static let defaultDraftsPath = "_drafts"
    static let defaultAssetsPath = "assets"
    static let defaultServeCommand = "bundle exec jekyll serve"
    static let defaultAutoStartServerOnPostCreate = false

    var id: UUID = UUID()
    var name: String
    var path: String
    var postsPath: String = Self.defaultPostsPath
    var draftsPath: String = Self.defaultDraftsPath
    var assetsPath: String = Self.defaultAssetsPath
    var serveCommand: String = Self.defaultServeCommand
    var autoStartServerOnPostCreate: Bool = Self.defaultAutoStartServerOnPostCreate
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
        postsPath: String = Self.defaultPostsPath,
        draftsPath: String = Self.defaultDraftsPath,
        assetsPath: String = Self.defaultAssetsPath,
        serveCommand: String = Self.defaultServeCommand,
        autoStartServerOnPostCreate: Bool = Self.defaultAutoStartServerOnPostCreate,
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
        postsPath = try container.decodeIfPresent(String.self, forKey: .postsPath) ?? Self.defaultPostsPath
        draftsPath = try container.decodeIfPresent(String.self, forKey: .draftsPath) ?? Self.defaultDraftsPath
        assetsPath = try container.decodeIfPresent(String.self, forKey: .assetsPath) ?? Self.defaultAssetsPath
        serveCommand = try container.decodeIfPresent(String.self, forKey: .serveCommand) ?? Self.defaultServeCommand
        autoStartServerOnPostCreate = try container.decodeIfPresent(Bool.self, forKey: .autoStartServerOnPostCreate) ?? Self.defaultAutoStartServerOnPostCreate
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
