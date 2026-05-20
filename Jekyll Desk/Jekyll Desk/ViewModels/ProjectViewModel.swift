import Foundation
import AppKit

@MainActor
final class ProjectViewModel: ObservableObject {
    @Published var projects: [Project] = []
    @Published var selectedProject: Project?
    @Published var scannedPosts: [Post] = []

    private let defaultsKey = "JekyllDesk.projects"

    init() {
        load()
        selectedProject = projects.first
        refreshPosts()
    }

    func select(_ project: Project) {
        selectedProject = project
        refreshPosts()
    }

    @discardableResult
    func addProjectWithOpenPanel() -> Bool {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Add Project"

        guard panel.runModal() == .OK, let url = panel.url else { return false }

        var project = Project(name: url.lastPathComponent, path: url.path)
        if !ProjectScanner.looksLikeJekyllProject(url) {
            project.postsPath = "_posts"
        }
        project.templates = FrontMatterTemplate.defaults
        project.defaultTemplateID = FrontMatterTemplate.defaultPost.id

        projects.append(project)
        selectedProject = project
        save()
        refreshPosts()
        return true
    }

    func duplicateSelectedProject() {
        guard var project = selectedProject else { return }
        project.id = UUID()
        project.name += " Copy"
        projects.append(project)
        save()
    }

    func removeSelectedProject() {
        guard let selectedProject else { return }
        projects.removeAll { $0.id == selectedProject.id }
        self.selectedProject = projects.first
        save()
        refreshPosts()
    }

    func refreshPosts() {
        guard let selectedProject else {
            scannedPosts = []
            return
        }
        scannedPosts = ProjectScanner.scanPosts(project: selectedProject)
    }

    func updateSelectedProject(_ project: Project) {
        selectedProject = project
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index] = project
        }
        save()
    }

    func save() {
        guard let data = try? JSONEncoder().encode(projects) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    private func load() {
        guard
            let data = UserDefaults.standard.data(forKey: defaultsKey),
            let decoded = try? JSONDecoder().decode([Project].self, from: data)
        else { return }
        projects = migrate(decoded)
        if projects != decoded {
            save()
        }
    }

    private func migrate(_ projects: [Project]) -> [Project] {
        projects
            .filter { !Self.isSampleProject($0) }
            .map { project in
                var project = project
                project.templates.removeAll { $0.isLegacySample }
                if project.templates.isEmpty {
                    project.templates = FrontMatterTemplate.defaults
                }
                if project.defaultTemplateID == nil || !project.templates.contains(where: { $0.id == project.defaultTemplateID }) {
                    project.defaultTemplateID = project.templates.first?.id
                }
                return project
            }
    }

    private static func isSampleProject(_ project: Project) -> Bool {
        let sampleNames = ["my-jekyll-blog", "music-blog", "docs-site", "personal-notes"]
        let samplePath = "\(NSHomeDirectory())/Sites/\(project.name)"
        return sampleNames.contains(project.name) && project.path == samplePath
    }
}
