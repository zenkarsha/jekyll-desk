import SwiftUI
import AppKit

struct ProjectActionsMenu: View {
    @ObservedObject var appVM: AppViewModel

    var body: some View {
        Menu {
            Button("Open in Finder", systemImage: "folder") { openProject() }
            Button("Reveal _posts Folder", systemImage: "folder.badge.gearshape") { revealPosts() }
            Divider()
            Button(role: .destructive) {
                showRemoveConfirmation()
            } label: {
                Label("Remove Project", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .frame(width: 28, height: 28)
                .background(Color.panelBackground)
                .overlay(Circle().stroke(Color.appBorder))
                .clipShape(Circle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
    }

    private func openProject() {
        guard let path = appVM.projectVM.selectedProject?.path else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    private func revealPosts() {
        guard let project = appVM.projectVM.selectedProject else { return }
        NSWorkspace.shared.open(project.postsURL)
    }

    private func showRemoveConfirmation() {
        guard let project = appVM.projectVM.selectedProject else { return }
        let alert = NSAlert.removeProject(projectName: project.name)
        guard alert.runModal() == .alertSecondButtonReturn else { return }

        appVM.removeSelectedProject()
        NSAlert.projectRemoved(projectName: project.name).runModal()
    }
}

private extension NSAlert {
    static func removeProject(projectName: String) -> NSAlert {
        let alert = NSAlert()
        alert.messageText = "Remove Project?"
        alert.informativeText = "Remove \"\(projectName)\" from Jekyll Desk? This will not delete the project folder or any files."
        alert.icon = NSApp.applicationIconImage.zoomedAlertIcon(scale: 1.18)
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Remove")
        alert.buttons.last?.hasDestructiveAction = true
        return alert
    }

    static func projectRemoved(projectName: String) -> NSAlert {
        let alert = NSAlert()
        alert.messageText = "Project Removed"
        alert.informativeText = "\(projectName) was removed from Jekyll Desk."
        alert.icon = NSApp.applicationIconImage.zoomedAlertIcon(scale: 1.18)
        alert.addButton(withTitle: "OK")
        return alert
    }
}
