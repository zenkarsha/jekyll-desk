import Foundation
import Combine
import UserNotifications

@MainActor
final class AppViewModel: ObservableObject {
    @Published var projectVM = ProjectViewModel()
    @Published var editorVM = EditorViewModel()
    @Published var serverVM = JekyllServerViewModel()
    @Published var autoRefresh = true
    @Published var showSettings = false
    @Published var showNewTemplate = false
    @Published var editingTemplate: FrontMatterTemplate?
    @Published var previewRefreshID = UUID()
    @Published private(set) var previewURLString: String?
    @Published var currentTime = Date()

    private let buildService = JekyllBuildService()
    private var cancellables: Set<AnyCancellable> = []
    private var explicitBuildTask: Task<Void, Never>?

    init() {
        projectVM.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        editorVM.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        serverVM.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        serverVM.$buildVersion
            .dropFirst()
            .sink { [weak self] _ in
                guard let self, self.serverVM.state == .running, self.autoRefresh else { return }
                self.reloadPreview()
            }
            .store(in: &cancellables)

        serverVM.$buildActivity
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] activity in
                guard
                    let self,
                    activity == .idle,
                    self.serverVM.state == .running,
                    self.autoRefresh
                else { return }
                self.reloadPreview()
            }
            .store(in: &cancellables)

        editorVM.$markdownContent
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] _ in
                guard let self, self.editorVM.filepath != nil else { return }
                self.serverVM.markSaving()
                self.editorVM.scheduleAutosave(project: self.projectVM.selectedProject) { [weak self] sourceURL in
                    self?.buildPreviewAfterSave(sourceURL: sourceURL)
                }
            }
            .store(in: &cancellables)

        editorVM.$formValues
            .dropFirst()
            .sink { [weak self] _ in
                guard let self, self.editorVM.filepath != nil else { return }
                self.serverVM.markSaving()
                self.editorVM.scheduleFrontMatterUpdate(project: self.projectVM.selectedProject) { [weak self] sourceURL in
                    self?.buildPreviewAfterSave(sourceURL: sourceURL)
                }
            }
            .store(in: &cancellables)

        selectDefaultTemplateForCurrentProject()
    }

    func reloadPreview() {
        syncPreviewURL()
        previewRefreshID = UUID()
    }

    func waitForSavedPostPreview(sourceURL: URL) {
        syncPreviewURL(sourceURL: sourceURL)
        buildPreviewAfterSave(sourceURL: sourceURL)
    }

    func createOrUpdatePost() {
        guard editorVM.validateRequiredFields() else { return }

        let isCreatingPost = editorVM.filepath == nil
        editorVM.generateAndApplyFrontMatter()
        let savedURL = editorVM.save(project: projectVM.selectedProject)
        projectVM.refreshPosts()

        guard let savedURL else { return }

        if isCreatingPost, projectVM.selectedProject?.autoStartServerOnPostCreate == true {
            serverVM.start(project: projectVM.selectedProject)
            syncPreviewURL(sourceURL: savedURL)
            return
        }

        waitForSavedPostPreview(sourceURL: savedURL)
    }

    func buildPreviewAfterSave(sourceURL: URL) {
        guard let project = projectVM.selectedProject else { return }
        syncPreviewURL(sourceURL: sourceURL)
        let expectedOutputURL = expectedPreviewOutputURL(sourceURL: sourceURL)
        let previousModifiedAt = expectedOutputURL.flatMap(fileModifiedAt)
        explicitBuildTask?.cancel()
        serverVM.markBuildPending()
        explicitBuildTask = Task { [weak self, buildService] in
            do {
                let output = try await buildService.build(project: project)
                await Self.waitForPreviewOutput(url: expectedOutputURL, previousModifiedAt: previousModifiedAt)
                await MainActor.run {
                    guard let self, !Task.isCancelled else { return }
                    self.syncPreviewURL(sourceURL: sourceURL)
                    self.serverVM.finishExplicitBuild(output: output)
                    if self.autoRefresh {
                        self.reloadPreview()
                    }
                }
            } catch is CancellationError {
                return
            } catch {
                await MainActor.run {
                    guard let self, !Task.isCancelled else { return }
                    self.serverVM.failExplicitBuild(error.localizedDescription)
                }
            }
        }
    }

    func syncPreviewURL(sourceURL: URL? = nil) {
        guard
            let project = projectVM.selectedProject,
            editorVM.filepath != nil || !editorVM.markdownContent.isEmpty
        else {
            previewURLString = nil
            return
        }

        let editorURL = editorVM.filepath.map(URL.init(fileURLWithPath:))
        let sourceURL = sourceURL ?? editorURL
        previewURLString = previewURLString(project: project, sourceURL: sourceURL)
    }

    func selectProject(_ project: Project) {
        projectVM.select(project)
        editorVM.resetPost()
        selectDefaultTemplateForCurrentProject()
    }

    func addProjectWithOpenPanel() {
        guard projectVM.addProjectWithOpenPanel() else { return }
        editorVM.resetPost()
        selectDefaultTemplateForCurrentProject()
    }

    func removeSelectedProject() {
        projectVM.removeSelectedProject()
        editorVM.resetPost()
        selectDefaultTemplateForCurrentProject()
    }

    func setDefaultTemplate(_ template: FrontMatterTemplate) {
        guard var project = projectVM.selectedProject else { return }
        project.defaultTemplateID = template.id
        projectVM.updateSelectedProject(project)
        editorVM.selectTemplate(template)
    }

    func saveTemplate(_ template: FrontMatterTemplate) {
        guard var project = projectVM.selectedProject else { return }
        if let index = project.templates.firstIndex(where: { $0.id == template.id }) {
            project.templates[index] = template
        } else {
            project.templates.append(template)
        }
        projectVM.updateSelectedProject(project)
        editorVM.selectTemplate(template)
    }

    func removeTemplate(_ template: FrontMatterTemplate) {
        guard var project = projectVM.selectedProject else { return }
        project.templates.removeAll { $0.id == template.id }
        if project.defaultTemplateID == template.id {
            project.defaultTemplateID = project.templates.first?.id
        }
        projectVM.updateSelectedProject(project)

        if editorVM.selectedTemplate.id == template.id {
            let fallback = project.templates.first ?? FrontMatterTemplate.defaultPost
            editorVM.selectTemplate(fallback)
        }

        sendTemplateRemovedNotification(template)
    }

    private func selectDefaultTemplateForCurrentProject() {
        guard let template = projectVM.selectedProject?.defaultTemplate else { return }
        editorVM.selectTemplate(template)
    }

    private func expectedPreviewOutputURL(sourceURL: URL) -> URL? {
        guard let project = projectVM.selectedProject,
              let previewURL = URL(string: previewURLString(project: project, sourceURL: sourceURL)),
              let components = URLComponents(url: previewURL, resolvingAgainstBaseURL: false) else {
            return nil
        }

        var path = components.percentEncodedPath.removingPercentEncoding ?? components.path
        let baseURL = configValue("baseurl", project: project).map(normalizedPath) ?? ""
        if !baseURL.isEmpty, path == baseURL || path.hasPrefix(baseURL + "/") {
            path.removeFirst(baseURL.count)
        }

        let relativePath = normalizedPath(path).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let siteURL = URL(fileURLWithPath: project.path).appendingPathComponent("_site")
        if relativePath.isEmpty {
            return siteURL.appendingPathComponent("index.html")
        }

        let url = siteURL.appendingPathComponent(relativePath)
        if url.pathExtension.isEmpty {
            return url.appendingPathComponent("index.html")
        }
        return url
    }

    private func previewURLString(project: Project, sourceURL: URL?) -> String {
        let origin = project.previewBaseURL
        let baseURL = configValue("baseurl", project: project).map(normalizedPath) ?? ""

        if let permalink = frontMatterValue("permalink"), !permalink.isEmpty {
            if permalink.hasPrefix("http://") || permalink.hasPrefix("https://") {
                return permalink
            }
            return origin + normalizedPath(baseURL + "/" + permalink)
        }

        if let permalinkPattern = configValue("permalink", project: project), !permalinkPattern.isEmpty {
            return origin + normalizedPath(baseURL + "/" + postPath(fromPermalink: permalinkPattern, sourceURL: sourceURL))
        }

        return origin + normalizedPath(baseURL + "/" + defaultPostPath(sourceURL: sourceURL))
    }

    private func defaultPostPath(sourceURL: URL?) -> String {
        let filename = sourceURL?.lastPathComponent ?? editorVM.filename
        let parts = (filename as NSString).deletingPathExtension.components(separatedBy: "-")
        guard parts.count >= 4 else {
            return editorVM.title.urlPathSegment + ".html"
        }

        let year = parts[0]
        let month = parts[1]
        let day = parts[2]
        let slug = parts.dropFirst(3).joined(separator: "-")
        let categories = postCategories()

        let pathParts: [String] = categories + [year, month, day, slug + ".html"]
        return pathParts
            .filter { !$0.isEmpty }
            .map(\.urlPathSegment)
            .joined(separator: "/")
    }

    private func postPath(fromPermalink pattern: String, sourceURL: URL?) -> String {
        let pattern = expandedPermalinkPattern(pattern)
        let filename = sourceURL?.lastPathComponent ?? editorVM.filename
        let parts = (filename as NSString).deletingPathExtension.components(separatedBy: "-")
        guard parts.count >= 4 else {
            return editorVM.title.urlPathSegment + ".html"
        }

        let year = parts[0]
        let month = parts[1]
        let day = parts[2]
        let slug = parts.dropFirst(3).joined(separator: "-")
        let categories = postCategories()
        let category = categories.first ?? ""
        let outputExt = ".html"
        let yDay = dayOfYear(year: year, month: month, day: day)

        let rawPath = pattern
            .replacingOccurrences(of: ":categories", with: categories.joined(separator: "/"))
            .replacingOccurrences(of: ":category", with: category)
            .replacingOccurrences(of: ":year", with: year)
            .replacingOccurrences(of: ":month", with: month)
            .replacingOccurrences(of: ":i_month", with: String(Int(month) ?? 0))
            .replacingOccurrences(of: ":day", with: day)
            .replacingOccurrences(of: ":i_day", with: String(Int(day) ?? 0))
            .replacingOccurrences(of: ":y_day", with: yDay)
            .replacingOccurrences(of: ":title", with: slug)
            .replacingOccurrences(of: ":slug", with: slug)
            .replacingOccurrences(of: ":name", with: slug)
            .replacingOccurrences(of: ":output_ext", with: outputExt)

        return normalizedPath(rawPath)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .components(separatedBy: "/")
            .filter { !$0.isEmpty }
            .map(\.urlPathSegment)
            .joined(separator: "/")
    }

    private func expandedPermalinkPattern(_ pattern: String) -> String {
        switch pattern.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "date":
            return "/:categories/:year/:month/:day/:title:output_ext"
        case "pretty":
            return "/:categories/:year/:month/:day/:title/"
        case "ordinal":
            return "/:categories/:year/:y_day/:title:output_ext"
        case "none":
            return "/:categories/:title:output_ext"
        default:
            return pattern
        }
    }

    private func dayOfYear(year: String, month: String, day: String) -> String {
        guard
            let year = Int(year),
            let month = Int(month),
            let day = Int(day),
            let date = Calendar(identifier: .gregorian).date(from: DateComponents(year: year, month: month, day: day))
        else {
            return day
        }

        return String(format: "%03d", Calendar(identifier: .gregorian).ordinality(of: .day, in: .year, for: date) ?? day)
    }

    private func frontMatterValue(_ key: String) -> String? {
        guard let range = FrontMatterParser.frontMatterBlock(in: editorVM.markdownContent) else { return nil }
        let frontMatter = String(editorVM.markdownContent[range])
        return frontMatter
            .components(separatedBy: .newlines)
            .first { $0.trimmingCharacters(in: .whitespaces).hasPrefix("\(key):") }
            .flatMap { line in
                line.split(separator: ":", maxSplits: 1).last
            }
            .map { value in
                String(value)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            }
    }

    private func configValue(_ key: String, project: Project) -> String? {
        let configURL = URL(fileURLWithPath: project.path).appendingPathComponent("_config.yml")
        guard let config = try? String(contentsOf: configURL, encoding: .utf8) else { return nil }

        return config
            .components(separatedBy: .newlines)
            .first { $0.trimmingCharacters(in: .whitespaces).hasPrefix("\(key):") }
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
            }
    }

    private func normalizedPath(_ path: String) -> String {
        let collapsed = path
            .components(separatedBy: "/")
            .filter { !$0.isEmpty }
            .joined(separator: "/")
        return collapsed.isEmpty ? "" : "/" + collapsed
    }

    private func postCategories() -> [String] {
        if let categories = frontMatterValue("categories") {
            let parsed = postCategories(from: categories)
            if !parsed.isEmpty {
                return parsed
            }
        }

        let category = (frontMatterValue("category") ?? editorVM.category)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))

        return category.isEmpty ? [] : [category]
    }

    private func postCategories(from value: String) -> [String] {
        value
            .replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")
            .split { $0 == "," || $0 == " " }
            .map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            }
            .filter { !$0.isEmpty }
    }

    private func fileModifiedAt(_ url: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate]) as? Date
    }

    private static func waitForPreviewOutput(url: URL?, previousModifiedAt: Date?) async {
        guard let url else { return }

        for _ in 0..<20 {
            if Task.isCancelled { return }
            if let modifiedAt = fileModifiedAt(url) {
                if previousModifiedAt == nil || modifiedAt > previousModifiedAt! {
                    return
                }
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    private static func fileModifiedAt(_ url: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate]) as? Date
    }

    private func sendTemplateRemovedNotification(_ template: FrontMatterTemplate) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }

            let content = UNMutableNotificationContent()
            content.title = "Template Removed"
            content.body = "\(template.name) has been removed."

            let request = UNNotificationRequest(
                identifier: "template-removed-\(template.id.uuidString)",
                content: content,
                trigger: nil
            )
            center.add(request)
        }
    }
}

private extension String {
    var urlPathSegment: String {
        addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? self
    }
}
