import Foundation

enum ProjectScanner {
    static func looksLikeJekyllProject(_ url: URL) -> Bool {
        let config = url.appendingPathComponent("_config.yml")
        let posts = url.appendingPathComponent("_posts")
        return FileManager.default.fileExists(atPath: config.path) || FileManager.default.fileExists(atPath: posts.path)
    }

    static func ensureFolders(for project: Project) throws {
        try FileManager.default.createDirectory(at: project.postsURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project.draftsURL, withIntermediateDirectories: true)
    }

    static func scanPosts(project: Project) -> [Post] {
        let urls = scanMarkdown(in: project.postsURL) + scanMarkdown(in: project.draftsURL)
        return urls.map { url in
            let content = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            let frontMatter = FrontMatterParser.frontMatterBlock(in: content).map { String(content[$0]) } ?? ""
            return Post(
                title: url.deletingPathExtension().lastPathComponent,
                filename: url.lastPathComponent,
                filepath: url.path,
                markdownContent: content,
                frontMatter: frontMatter,
                status: url.path.contains("/\(project.draftsPath)/") ? .draft : .post,
                previewUrl: project.previewBaseURL
            )
        }
    }

    private static func scanMarkdown(in folder: URL) -> [URL] {
        guard let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else {
            return []
        }
        return files.filter { ["md", "markdown"].contains($0.pathExtension.lowercased()) }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}
