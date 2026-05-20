import SwiftUI

struct SettingsPanelView: View {
    @ObservedObject var appVM: AppViewModel
    @State private var serveCommand = Project.defaultServeCommand
    @State private var autoStart = Project.defaultAutoStartServerOnPostCreate

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Settings")
                    .font(.title3.weight(.semibold))
                Spacer()
                IconButton(systemName: "xmark") {
                    saveProjectServeSettings()
                    withAnimation(.easeOut(duration: 0.18)) {
                        appVM.showSettings = false
                    }
                }
            }
            .padding(22)
            Divider()

            VStack(spacing: 20) {
                group("GENERAL") {
                    picker("Editor Font Size", selection: editorFontSizeSelection, values: ["12 px", "13 px", "14 px", "15 px", "16 px"])
                    picker("Tab Size", selection: editorTabSizeSelection, values: ["2", "4"])
                    settingToggle("Word Wrap", subtitle: "Wrap long lines in the editor", isOn: $appVM.editorVM.wordWrap)
                    settingToggle("Show Line Numbers", subtitle: "Display line numbers in the editor", isOn: $appVM.editorVM.lineNumbers)
                }

                group("JEKYLL SERVE", showsDivider: false) {
                    text("Serve Command", value: $serveCommand)
                    settingToggle("Auto Start Server When Post Create", subtitle: "", isOn: $autoStart)
                }
            }
            .padding(22)

            Divider()
            HStack {
                Button("Reset to Default") {
                    resetToDefault()
                }
                    .buttonStyle(AppSecondaryButtonStyle(width: 148))
                Spacer()
                Button("Done") {
                    saveProjectServeSettings()
                    appVM.showSettings = false
                }
                .buttonStyle(AppPrimaryButtonStyle())
            }
            .padding(22)
        }
        .background(Color.panelBackground)
        .foregroundStyle(Color.primaryText)
        .preferredColorScheme(.light)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.18), radius: 24, x: 0, y: 12)
        .onAppear {
            loadProjectServeSettings()
        }
        .onChange(of: appVM.projectVM.selectedProject?.id) { _, _ in
            loadProjectServeSettings()
        }
    }

    private func loadProjectServeSettings() {
        guard let project = appVM.projectVM.selectedProject else {
            serveCommand = Project.defaultServeCommand
            autoStart = Project.defaultAutoStartServerOnPostCreate
            return
        }

        serveCommand = project.serveCommand
        autoStart = project.autoStartServerOnPostCreate
    }

    private func saveProjectServeSettings() {
        guard var project = appVM.projectVM.selectedProject else { return }

        let command = serveCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        project.serveCommand = command.isEmpty ? Project.defaultServeCommand : command
        project.autoStartServerOnPostCreate = autoStart
        appVM.projectVM.updateSelectedProject(project)
        appVM.syncPreviewURL()
    }

    private func resetToDefault() {
        appVM.editorVM.resetSettingsToDefault()
        serveCommand = Project.defaultServeCommand
        autoStart = Project.defaultAutoStartServerOnPostCreate
        saveProjectServeSettings()
    }

    private func group<Content: View>(_ title: String, showsDivider: Bool = true, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
            if showsDivider {
                Divider()
            }
        }
    }

    private func picker(_ title: String, selection: Binding<String>, values: [String]) -> some View {
        HStack {
            Text(title).fontWeight(.medium)
            Spacer()
            AppSettingsDropdown(selection: selection, values: values)
        }
    }

    private func text(_ title: String, value: Binding<String>) -> some View {
        HStack {
            Text(title).fontWeight(.medium)
            Spacer()
            TextField(title, text: value)
                .appModalInputStyle()
                .frame(width: 230)
        }
    }

    private func settingToggle(_ title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).fontWeight(.medium)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .labelsHidden()
            .tint(Color.appBlue)
        }
    }

    private var editorFontSizeSelection: Binding<String> {
        Binding(
            get: { "\(appVM.editorVM.fontSize) px" },
            set: { value in
                guard let size = Int(value.replacingOccurrences(of: " px", with: "")) else { return }
                appVM.editorVM.setFontSize(size)
            }
        )
    }

    private var editorTabSizeSelection: Binding<String> {
        Binding(
            get: { "\(appVM.editorVM.tabSize)" },
            set: { value in
                guard let size = Int(value) else { return }
                appVM.editorVM.setTabSize(size)
            }
        )
    }
}
