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

    private static func moveFile(from sourceURL: URL, to destinationURL: URL) throws {
        guard sourceURL.standardizedFileURL != destinationURL.standardizedFileURL else { return }
        guard !FileManager.default.fileExists(atPath: destinationURL.path) else {
            throw CocoaError(.fileWriteFileExists)
        }
        try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
    }
}
