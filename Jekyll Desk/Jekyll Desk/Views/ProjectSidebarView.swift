import SwiftUI
import AppKit

struct ProjectSidebarView: View {
    @ObservedObject var appVM: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                if appVM.projectVM.selectedProject == nil {
                    sidebarEmptyState
                } else {
                    VStack(alignment: .leading, spacing: 13) {
                        projectSection
                        FrontMatterTemplateListView(appVM: appVM)
                        YamlTemplatePreviewView(template: appVM.editorVM.selectedTemplate)
                        PostFormView(appVM: appVM)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 18)
                }
            }
            if appVM.projectVM.selectedProject != nil {
                fixedCreateButton
            }
        }
        .background(Color.appBackground)
    }

    private var fixedCreateButton: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                appVM.createOrUpdatePost()
            } label: {
                Label(createButtonTitle, systemImage: createButtonIcon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(Color.appBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .shadow(color: Color.appBlue.opacity(0.18), radius: 8, y: 2)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color.appBackground)
    }

    private var isEditingExistingPost: Bool {
        appVM.editorVM.filepath != nil
    }

    private var createButtonTitle: String {
        isEditingExistingPost ? "Update Post" : "Create Post"
    }

    private var createButtonIcon: String {
        isEditingExistingPost ? "square.and.pencil" : "plus.circle.fill"
    }

    private var projectSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle("PROJECT")
            HStack(spacing: 10) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 31))
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(appVM.projectVM.selectedProject?.name ?? "No Project")
                        .font(.system(size: 14, weight: .semibold))
                    Text(appVM.projectVM.selectedProject?.displayPath ?? "Add a Jekyll project")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                ProjectActionsMenu(appVM: appVM)
            }
        }
    }

    private var sidebarEmptyState: some View {
        VStack(spacing: 13) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 36, weight: .regular))
                .foregroundStyle(Color.secondaryText)
            Text("Add a project")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.primaryText)
            Text("Choose a Jekyll folder to start creating posts.")
                .font(.system(size: 13))
                .foregroundStyle(Color.secondaryText)
                .multilineTextAlignment(.center)
            Button {
                appVM.addProjectWithOpenPanel()
            } label: {
                Label("Add Project", systemImage: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .frame(width: 132, height: 34)
                    .background(Color.appBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 22)
        .padding(.top, 96)
    }
}
