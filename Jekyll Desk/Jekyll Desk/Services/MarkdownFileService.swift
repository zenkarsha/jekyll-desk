import Foundation
import AppKit

enum MarkdownFileService {
    static func defaultMarkdown(title: String, multiVideo: Bool) -> String {
        """
        Write your content here.
        """
    }

    static func filename(date: String, title: String) -> String {
        "\(date)-\(SlugService.slugify(title)).md"
    }

    static func save(content: String, project: Project, title: String, date: String, existingPath: String?) throws -> URL {
        try ProjectScanner.ensureFolders(for: project)
        let url = existingPath.map(URL.init(fileURLWithPath:)) ?? project.postsURL.appendingPathComponent(filename(date: date, title: title))
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    static func importImages(_ sourceURLs: [URL], project: Project, postFilename: String, title: String, date: String) throws -> [String] {
        let imageURLs = sourceURLs.filter { $0.isFileURL && isImageFile($0) }
        guard !imageURLs.isEmpty else { return [] }

        let folderName = imageFolderName(postFilename: postFilename, title: title, date: date)
        let destinationFolder = URL(fileURLWithPath: project.path)
            .appendingPathComponent(project.assetsPath)
            .appendingPathComponent("images")
            .appendingPathComponent("posts")
            .appendingPathComponent(folderName)

        try FileManager.default.createDirectory(at: destinationFolder, withIntermediateDirectories: true)

        return try imageURLs.map { sourceURL in
            let destinationURL = uniqueImageURL(for: sourceURL, in: destinationFolder)
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            return markdownImagePath(project: project, folderName: folderName, filename: destinationURL.lastPathComponent)
        }
    }

    static func rename(post: Post, to filename: String) throws -> URL {
        let sourceURL = URL(fileURLWithPath: post.filepath)
        let sanitizedFilename = normalizedMarkdownFilename(filename)
        let destinationURL = sourceURL.deletingLastPathComponent().appendingPathComponent(sanitizedFilename)
        try moveFile(from: sourceURL, to: destinationURL)
        return destinationURL
    }

    static func moveToDrafts(post: Post, project: Project) throws -> URL {
        try ProjectScanner.ensureFolders(for: project)
        let sourceURL = URL(fileURLWithPath: post.filepath)
        let destinationURL = project.draftsURL.appendingPathComponent(sourceURL.lastPathComponent)
        try moveFile(from: sourceURL, to: destinationURL)
        return destinationURL
    }

    static func moveToPosts(post: Post, project: Project) throws -> URL {
        try ProjectScanner.ensureFolders(for: project)
        let sourceURL = URL(fileURLWithPath: post.filepath)
        let destinationURL = project.postsURL.appendingPathComponent(sourceURL.lastPathComponent)
        try moveFile(from: sourceURL, to: destinationURL)
        return destinationURL
    }

    static func export(post: Post, to destinationURL: URL) throws {
        try post.markdownContent.write(to: destinationURL, atomically: true, encoding: .utf8)
    }

    static func moveToTrash(post: Post) throws {
        var result: NSURL?
        try FileManager.default.trashItem(at: URL(fileURLWithPath: post.filepath), resultingItemURL: &result)
    }

    static func normalizedMarkdownFilename(_ filename: String) -> String {
        let trimmed = filename.trimmingCharacters(in: .whitespacesAndNewlines)
        guard URL(fileURLWithPath: trimmed).pathExtension.isEmpty else { return trimmed }
        return trimmed + ".md"
    }

    private static func imageFolderName(postFilename: String, title: String, date: String) -> String {
        let postName = URL(fileURLWithPath: postFilename).deletingPathExtension().lastPathComponent
        if postName != "Untitled", !postName.isEmpty {
            return postName
        }
        return URL(fileURLWithPath: filename(date: date, title: title)).deletingPathExtension().lastPathComponent
    }

    private static func uniqueImageURL(for sourceURL: URL, in folderURL: URL) -> URL {
        let sourceExtension = sourceURL.pathExtension.lowercased()
        let sourceBaseName = sourceURL.deletingPathExtension().lastPathComponent
        let baseName = SlugService.slugify(sourceBaseName).isEmpty ? "image" : SlugService.slugify(sourceBaseName)
        let fileExtension = sourceExtension.isEmpty ? "png" : sourceExtension
        var candidate = folderURL.appendingPathComponent("\(baseName).\(fileExtension)")
        var index = 1

        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folderURL.appendingPathComponent("\(baseName)-\(index).\(fileExtension)")
            index += 1
        }

        return candidate
    }

    private static func markdownImagePath(project: Project, folderName: String, filename: String) -> String {
        let path = [baseURL(for: project), project.assetsPath, "images", "posts", folderName, filename]
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "/")) }
            .filter { !$0.isEmpty }
            .joined(separator: "/")
        return "/" + path
    }

    private static func baseURL(for project: Project) -> String {
        let configURL = URL(fileURLWithPath: project.path).appendingPathComponent("_config.yml")
        guard let config = try? String(contentsOf: configURL, encoding: .utf8) else { return "" }

        return config
            .components(separatedBy: .newlines)
            .first { $0.trimmingCharacters(in: .whitespaces).hasPrefix("baseurl:") }
            .flatMap { line in
                line.split(separator: ":", maxSplits: 1).last
            }
            .map { value in
                String(value)
                    .split(separator: "#", maxSplits: 1)
                    .first
                    .map(String.init) ?? ""
            }
            .map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            } ?? ""
    }

    private static func isImageFile(_ url: URL) -> Bool {
        ["apng", "avif", "gif", "jpeg", "jpg", "png", "svg", "webp"].contains(url.pathExtension.lowercased())
    }

    private static func moveFile(from sourceURL: URL, to destinationURL: URL) throws {
        guard sourceURL.standardizedFileURL != destinationURL.standardizedFileURL else { return }
        guard !FileManager.default.fileExists(atPath: destinationURL.path) else {
            throw CocoaError(.fileWriteFileExists)
        }
        try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
    }
}
