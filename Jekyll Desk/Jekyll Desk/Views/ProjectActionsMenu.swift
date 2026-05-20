import SwiftUI
import AppKit

struct ProjectActionsMenu: View {
    @ObservedObject var appVM: AppViewModel
    @State private var projectPendingRemoval: Project?
    @State private var removedProjectName: String?

    var body: some View {
        Menu {
            Button("Open in Finder", systemImage: "folder") { openProject() }
            Button("Reveal _posts Folder", systemImage: "folder.badge.gearshape") { revealPosts() }
            Divider()
            Button(role: .destructive) {
                projectPendingRemoval = appVM.projectVM.selectedProject
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
        .alert("Remove Project?", isPresented: removeConfirmationBinding, presenting: projectPendingRemoval) { project in
            Button("Cancel", role: .cancel) {
                projectPendingRemoval = nil
            }
            Button("Remove", role: .destructive) {
                removedProjectName = project.name
                appVM.removeSelectedProject()
                projectPendingRemoval = nil
            }
        } message: { project in
            Text("Remove \"\(project.name)\" from Jekyll Desk? This will not delete the project folder or any files.")
        }
        .alert("Project Removed", isPresented: removalSuccessBinding) {
            Button("OK", role: .cancel) {
                removedProjectName = nil
            }
        } message: {
            Text("\(removedProjectName ?? "Project") was removed from Jekyll Desk.")
        }
    }

    private var removeConfirmationBinding: Binding<Bool> {
        Binding(
            get: { projectPendingRemoval != nil },
            set: { if !$0 { projectPendingRemoval = nil } }
        )
    }

    private var removalSuccessBinding: Binding<Bool> {
        Binding(
            get: { removedProjectName != nil },
            set: { if !$0 { removedProjectName = nil } }
        )
    }

    private func openProject() {
        guard let path = appVM.projectVM.selectedProject?.path else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    private func revealPosts() {
        guard let project = appVM.projectVM.selectedProject else { return }
        NSWorkspace.shared.open(project.postsURL)
    }
}
