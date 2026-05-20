import SwiftUI

struct MarkdownEditorView: View {
    @ObservedObject var appVM: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            header
            editor
        }
        .background(Color.panelBackground)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle("MARKDOWN EDITOR")
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

            ZStack(alignment: .bottomLeading) {
                Divider()
                    .padding(.top, 39)

                HStack(alignment: .bottom, spacing: 8) {
                    if hasEditablePost {
                        fileTab
                    } else if appVM.projectVM.selectedProject != nil {
                        fakeFileTab
                    }
                    Spacer()
                    EditorLayoutMenu(appVM: appVM)
                }
                .padding(.horizontal, 16)
            }
            .frame(height: 40)
        }
        .frame(height: 76, alignment: .top)
    }

    private var fileTab: some View {
        HStack(spacing: 6) {
            Image(systemName: fileTabIcon)
                .font(.system(size: 13))
            Text(appVM.editorVM.filename)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 6)
            FileActionsMenu(appVM: appVM)
            Button {
                appVM.editorVM.resetPost()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 22, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .font(.system(size: 12))
        .foregroundStyle(Color.primaryText)
        .padding(.horizontal, 10)
        .frame(width: 240, height: 36, alignment: .leading)
        .background(Color.panelBackground)
        .overlay(FileTabBorder(radius: 7).stroke(Color.appBorder, lineWidth: 1))
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 7,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 7,
                style: .continuous
            )
        )
        .offset(y: 1)
    }

    private var fakeFileTab: some View {
        HStack(spacing: 6) {
            Image(systemName: "doc.text")
                .font(.system(size: 13))
            Text("Untitled.md")
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 6)
            Image(systemName: "ellipsis")
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 18, height: 30)
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 22, height: 28)
        }
        .font(.system(size: 12))
        .foregroundStyle(Color.secondaryText)
        .padding(.horizontal, 10)
        .frame(width: 240, height: 36, alignment: .leading)
        .background(Color.panelBackground)
        .overlay(FileTabBorder(radius: 7).stroke(Color.appBorder, lineWidth: 1))
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 7,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 7,
                style: .continuous
            )
        )
        .offset(y: 1)
    }

    private var editor: some View {
        Group {
            if appVM.projectVM.selectedProject == nil {
                editorMessageState(
                    icon: "folder.badge.plus",
                    title: "Add a project",
                    message: "Choose a Jekyll folder before editing markdown."
                )
            } else if !hasEditablePost {
                lockedEmptyEditor
            } else {
                markdownTextEditor
            }
        }
    }

    private var markdownTextEditor: some View {
        HStack(alignment: .top, spacing: 0) {
            if appVM.editorVM.lineNumbers {
                lineNumberGutter
            }

            SyntaxMarkdownTextView(text: Binding(
                get: { appVM.editorVM.markdownContent },
                set: {
                    appVM.editorVM.markdownContent = $0
                }
            ), project: appVM.projectVM.selectedProject, postFilename: appVM.editorVM.filename, postTitle: appVM.editorVM.title, postDate: appVM.editorVM.date, wordWrap: appVM.editorVM.wordWrap, fontSize: CGFloat(appVM.editorVM.fontSize), tabSize: appVM.editorVM.tabSize) { _ in }
            .background(Color.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var lineNumberGutter: some View {
        lineNumberGutter(lineCount: max(1, appVM.editorVM.markdownContent.components(separatedBy: .newlines).count))
    }

    private func lineNumberGutter(lineCount: Int) -> some View {
        ScrollView {
            VStack(alignment: .trailing, spacing: 0) {
                ForEach(1...lineCount, id: \.self) { line in
                    Text("\(line)")
                        .font(.system(size: CGFloat(max(11, appVM.editorVM.fontSize - 1)), design: .monospaced))
                        .foregroundStyle(Color.secondaryText)
                        .frame(height: CGFloat(appVM.editorVM.fontSize + 10))
                }
            }
            .padding(.top, 13)
            .padding(.horizontal, 10)
        }
        .frame(width: 44)
        .background(Color(red: 0.949, green: 0.957, blue: 0.969))
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.appBorder.opacity(0.75))
                .frame(width: 1)
        }
    }

    private var lockedEmptyEditor: some View {
        ZStack {
            fakeMarkdownEditor
            Color.black.opacity(0.045)
            editorOverlayMessage(
                icon: "doc.badge.plus",
                title: "Create a post first",
                message: "Generate a markdown post from the selected front matter template."
            )
        }
    }

    private var fakeMarkdownEditor: some View {
        HStack(alignment: .top, spacing: 0) {
            lineNumberGutter(lineCount: 28)
            Color.white
        }
        .background(Color.white)
    }

    private var hasEditablePost: Bool {
        appVM.editorVM.filepath != nil || !appVM.editorVM.markdownContent.isEmpty
    }

    private var fileTabIcon: String {
        guard
            let filepath = appVM.editorVM.filepath,
            let draftsPath = appVM.projectVM.selectedProject?.draftsPath
        else { return "doc.text" }

        return filepath.contains("/\(draftsPath)/") ? "doc.badge.clock" : "doc.text"
    }

    private func editorMessageState(
        icon: String,
        title: String,
        message: String
    ) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(Color.secondaryText)
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.primaryText)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }

    private func editorOverlayMessage(
        icon: String,
        title: String,
        message: String
    ) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(Color.secondaryText)
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.primaryText)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct FileTabBorder: Shape {
    var radius: CGFloat = 7

    func path(in rect: CGRect) -> Path {
        let minX = rect.minX + 0.5
        let maxX = rect.maxX - 0.5
        let minY = rect.minY + 0.5
        let maxY = rect.maxY

        var path = Path()
        path.move(to: CGPoint(x: minX, y: maxY))
        path.addLine(to: CGPoint(x: minX, y: minY + radius))
        path.addQuadCurve(
            to: CGPoint(x: minX + radius, y: minY),
            control: CGPoint(x: minX, y: minY)
        )
        path.addLine(to: CGPoint(x: maxX - radius, y: minY))
        path.addQuadCurve(
            to: CGPoint(x: maxX, y: minY + radius),
            control: CGPoint(x: maxX, y: minY)
        )
        path.addLine(to: CGPoint(x: maxX, y: maxY))
        return path
    }
}
