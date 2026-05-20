import SwiftUI

struct MainWindowView: View {
    @StateObject private var appVM = AppViewModel()

    var body: some View {
        VStack(spacing: 0) {
            TopToolbarView(appVM: appVM)
                .frame(height: 58)

            Divider()

            HStack(spacing: 0) {
                ProjectSidebarView(appVM: appVM)
                    .frame(width: 368)
                Divider()
                if appVM.editorVM.layoutMode != .previewOnly {
                    MarkdownEditorView(appVM: appVM)
                        .frame(minWidth: appVM.editorVM.layoutMode == .editorOnly ? 860 : 410)
                }
                if appVM.editorVM.layoutMode == .editorAndPreview {
                    Divider()
                }
                if appVM.editorVM.layoutMode != .editorOnly {
                    PreviewWebView(appVM: appVM)
                        .frame(minWidth: 430)
                }
            }

            Divider()
            StatusBarView(appVM: appVM)
                .frame(height: 42)
        }
        .background(Color.appBackground)
        .foregroundStyle(Color.primaryText)
        .preferredColorScheme(.light)
        .frame(minWidth: 1320, minHeight: 820)
        .overlay(alignment: .bottomTrailing) {
            if appVM.showSettings {
                SettingsPanelView(appVM: appVM)
                    .frame(width: 560)
                    .padding(.trailing, 28)
                    .padding(.bottom, 42)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $appVM.showNewTemplate) {
            NewTemplateModalView(appVM: appVM, template: appVM.editingTemplate)
                .frame(width: 620, height: 680)
        }
    }
}
