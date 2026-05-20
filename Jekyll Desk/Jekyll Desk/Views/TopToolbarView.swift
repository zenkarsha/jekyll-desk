import SwiftUI
import AppKit

struct TopToolbarView: View {
    @ObservedObject var appVM: AppViewModel
    @State private var showsProjectPopover = false

    var body: some View {
        HStack(spacing: 16) {
            Text("Project:")
                .font(.system(size: 14, weight: .medium))

            ProjectDropdownButton(appVM: appVM, isPresented: $showsProjectPopover)

            Text(appVM.projectVM.selectedProject?.displayPath ?? "No project selected")
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 260, alignment: .leading)

            Spacer()

            Button {
                guard canRunServer else { return }
                appVM.serverVM.toggle(project: appVM.projectVM.selectedProject)
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: appVM.serverVM.state == .running ? "stop.fill" : "play.fill")
                    Text(appVM.serverVM.state == .running ? "Stop Server" : "Run Jekyll Serve")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(runButtonForeground)
                .frame(width: 180, height: 36)
                .background(runButtonBackground)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .shadow(color: runButtonShadow, radius: 8, y: 2)
            }
            .buttonStyle(.plain)
            .disabled(!canRunServer)

            HStack(spacing: 8) {
                StatusDot(color: statusColor)
                Text(appVM.serverVM.statusLabel)
                    .font(.system(size: 14))
            }
            .frame(width: 228, alignment: .leading)

            Divider().frame(height: 28)

            Text("Auto Refresh")
                .font(.system(size: 14))
            Toggle("", isOn: $appVM.autoRefresh)
                .toggleStyle(.switch)
                .labelsHidden()
                .tint(Color.appBlue)

            Button {
                NSAlert.previewInfo().runModal()
            } label: {
                Image(systemName: "info.circle")
            }
            .buttonStyle(.borderless)

            Spacer()

            EditorPreviewLayoutMenu(appVM: appVM)

        }
        .padding(.horizontal, 22)
        .background(Color.toolbarBackground)
    }

    private var statusColor: Color {
        switch appVM.serverVM.state {
        case .running: .appGreen
        case .failed: .appRed
        case .stopped: .secondaryText
        }
    }

    private var runButtonBackground: Color {
        canRunServer ? Color.appBlue : Color(red: 0.875, green: 0.887, blue: 0.906)
    }

    private var runButtonForeground: Color {
        canRunServer ? Color.white : Color(red: 0.33, green: 0.37, blue: 0.44)
    }

    private var runButtonShadow: Color {
        canRunServer ? Color.appBlue.opacity(0.18) : Color.clear
    }

    private var canRunServer: Bool {
        appVM.projectVM.selectedProject != nil && hasEditablePost
    }

    private var hasEditablePost: Bool {
        appVM.editorVM.filepath != nil || !appVM.editorVM.markdownContent.isEmpty
    }
}

private extension NSAlert {
    static func previewInfo() -> NSAlert {
        let alert = NSAlert()
        alert.messageText = "Preview and Jekyll Serve"
        alert.informativeText = "Run Jekyll Serve starts the configured command in the selected project. Auto Refresh saves markdown changes and reloads the WebView after a short debounce."
        alert.icon = NSApp.applicationIconImage.zoomedAlertIcon(scale: 1.18)
        alert.addButton(withTitle: "OK")
        return alert
    }
}

private struct EditorPreviewLayoutMenu: View {
    @ObservedObject var appVM: AppViewModel

    var body: some View {
        Menu {
            layoutButton("Editor Only", mode: .editorOnly)
            layoutButton("Preview Only", mode: .previewOnly)
            layoutButton("Editor + Preview", mode: .editorAndPreview)
        } label: {
            Image(systemName: "rectangle.split.2x1")
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .menuIndicator(.hidden)
        .buttonStyle(.borderless)
    }

    private func layoutButton(_ title: String, mode: EditorLayoutMode) -> some View {
        Button {
            appVM.editorVM.layoutMode = mode
        } label: {
            layoutButtonLabel(title, mode: mode)
        }
    }

    @ViewBuilder
    private func layoutButtonLabel(_ title: String, mode: EditorLayoutMode) -> some View {
        if appVM.editorVM.layoutMode == mode {
            Label(title, systemImage: "checkmark")
        } else {
            Text(title)
        }
    }
}

private struct ProjectDropdownButton: View {
    @ObservedObject var appVM: AppViewModel
    @Binding var isPresented: Bool

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(Color.appBlue)
                Text(appVM.projectVM.selectedProject?.name ?? "Choose Project")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.primaryText)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.secondaryText)
            }
            .padding(.horizontal, 13)
            .frame(width: 240, height: 36)
            .background(Color.panelBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.appBorder, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPresented, arrowEdge: .top) {
            ProjectDropdownPopover(appVM: appVM, isPresented: $isPresented)
        }
    }
}

private struct ProjectDropdownPopover: View {
    @ObservedObject var appVM: AppViewModel
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(appVM.projectVM.projects) { project in
                projectRow(project)
            }

            if !appVM.projectVM.projects.isEmpty {
                Divider()
                    .padding(.vertical, 5)
            }

            Button {
                isPresented = false
                appVM.addProjectWithOpenPanel()
            } label: {
                HStack(spacing: 13) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.primaryText)
                        .frame(width: 22)
                    Text("Add Project...")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.primaryText)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 36)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .frame(width: 286)
        .background(Color.panelBackground)
        .preferredColorScheme(.light)
    }

    private func projectRow(_ project: Project) -> some View {
        let selected = project.id == appVM.projectVM.selectedProject?.id

        return Button {
            appVM.selectProject(project)
            isPresented = false
        } label: {
            HStack(spacing: 13) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(Color.appBlue)
                    .frame(width: 22)
                Text(project.name)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.primaryText)
                    .lineLimit(1)
                Spacer()
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.appBlue)
                }
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 38)
            .background(selected ? Color(red: 0.965, green: 0.972, blue: 0.982) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
