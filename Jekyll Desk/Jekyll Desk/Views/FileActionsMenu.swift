import SwiftUI
import AppKit

struct FileActionsMenu: View {
    @ObservedObject var appVM: AppViewModel
    @State private var showingRenameSheet = false
    @State private var showingDeleteConfirmation = false

    var body: some View {
        Menu {
            Button("Rename File") { showingRenameSheet = true }
            Button("Reveal in Finder") { revealInFinder() }
            Button("Open in External Editor") { openExternal() }
            Divider()
            Button(moveActionTitle) { movePost() }
            Button("Export Markdown") { exportMarkdown() }
            Divider()
            Button(role: .destructive) { showingDeleteConfirmation = true } label: {
                Text("Delete Post")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.primaryText)
                .frame(width: 18, height: 30)
                .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .sheet(isPresented: $showingRenameSheet) {
            RenameFileSheet(
                initialFilename: appVM.editorVM.filename,
                onCancel: { showingRenameSheet = false },
                onSave: { filename in
                    renameFile(to: filename)
                    showingRenameSheet = false
                }
            )
            .frame(width: 360, height: 156)
        }
        .alert("Delete Post?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deletePost()
            }
        } message: {
            Text("This moves the markdown file to Trash.")
        }
    }

    private func currentPost() -> Post? {
        guard let path = appVM.editorVM.filepath else { return nil }
        return Post(
            title: appVM.editorVM.title,
            filename: URL(fileURLWithPath: path).lastPathComponent,
            filepath: path,
            markdownContent: appVM.editorVM.markdownContent,
            frontMatter: "",
            previewUrl: appVM.projectVM.selectedProject?.previewBaseURL ?? ""
        )
    }

    private func renameFile(to filename: String) {
        guard let post = currentPost() else { return }
        guard isValidFilename(filename) else {
            appVM.serverVM.log += "\nInvalid filename: \(filename)"
            return
        }

        let sourceURL = URL(fileURLWithPath: post.filepath)
        let destinationURL = sourceURL
            .deletingLastPathComponent()
            .appendingPathComponent(MarkdownFileService.normalizedMarkdownFilename(filename))

        guard sourceURL.standardizedFileURL != destinationURL.standardizedFileURL else { return }

        do {
            let url = try MarkdownFileService.rename(post: post, to: filename)
            try writeCurrentEditorContentIfNeeded(to: url)
            appVM.editorVM.updateOpenedFile(to: url)
            appVM.projectVM.refreshPosts()
            appVM.reloadPreview()
            appVM.waitForSavedPostPreview(sourceURL: url)
        } catch {
            appVM.serverVM.log += "\nRename file failed: \(error.localizedDescription)"
        }
    }

    private func writeCurrentEditorContentIfNeeded(to url: URL) throws {
        let content = appVM.editorVM.markdownContent
        if (try? String(contentsOf: url, encoding: .utf8)) != content {
            try content.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private func revealInFinder() {
        guard let path = appVM.editorVM.filepath else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    private func openExternal() {
        guard let path = appVM.editorVM.filepath else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    private func movePost() {
        guard let post = currentPost(), let project = appVM.projectVM.selectedProject else { return }

        do {
            let url = isDraft
                ? try MarkdownFileService.moveToPosts(post: post, project: project)
                : try MarkdownFileService.moveToDrafts(post: post, project: project)
            try appVM.editorVM.markdownContent.write(to: url, atomically: true, encoding: .utf8)
            appVM.editorVM.updateOpenedFile(to: url)
            appVM.projectVM.refreshPosts()
            appVM.waitForSavedPostPreview(sourceURL: url)
        } catch {
            appVM.serverVM.log += "\nMove post failed: \(error.localizedDescription)"
        }
    }

    private func exportMarkdown() {
        guard let post = currentPost() else { return }

        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = post.filename

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try MarkdownFileService.export(post: post, to: url)
        } catch {
            appVM.serverVM.log += "\nExport markdown failed: \(error.localizedDescription)"
        }
    }

    private func deletePost() {
        guard let post = currentPost() else { return }
        do {
            try MarkdownFileService.moveToTrash(post: post)
            appVM.editorVM.resetPost(resetForm: true)
            appVM.serverVM.stop()
            appVM.reloadPreview()
            appVM.projectVM.refreshPosts()
        } catch {
            appVM.serverVM.log += "\nDelete post failed: \(error.localizedDescription)"
        }
    }

    private func isValidFilename(_ filename: String) -> Bool {
        let trimmed = filename.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty
            && !trimmed.contains("/")
            && !trimmed.contains(":")
    }

    private var moveActionTitle: String {
        isDraft ? "Move to Posts" : "Move to Drafts"
    }

    private var isDraft: Bool {
        guard
            let filepath = appVM.editorVM.filepath,
            let draftsPath = appVM.projectVM.selectedProject?.draftsPath
        else { return false }

        return filepath.contains("/\(draftsPath)/")
    }
}

private struct RenameFileSheet: View {
    let initialFilename: String
    let onCancel: () -> Void
    let onSave: (String) -> Void

    @State private var filename: String
    @FocusState private var isFocused: Bool

    init(initialFilename: String, onCancel: @escaping () -> Void, onSave: @escaping (String) -> Void) {
        self.initialFilename = initialFilename
        self.onCancel = onCancel
        self.onSave = onSave
        _filename = State(initialValue: initialFilename)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Rename File")
                .font(.system(size: 17, weight: .semibold))

            TextField("Filename", text: $filename)
                .appModalInputStyle()
                .focused($isFocused)
                .onSubmit(save)

            HStack {
                Spacer()
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(AppSecondaryButtonStyle())
                Button("Save") {
                    save()
                }
                .buttonStyle(AppPrimaryButtonStyle())
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
        }
        .padding(20)
        .onAppear {
            isFocused = true
        }
    }

    private var isValid: Bool {
        let trimmed = filename.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty
            && !trimmed.contains("/")
            && !trimmed.contains(":")
    }

    private func save() {
        guard isValid else { return }
        onSave(filename)
    }
}
