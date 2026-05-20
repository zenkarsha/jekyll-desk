import SwiftUI

struct EditorLayoutMenu: View {
    @ObservedObject var appVM: AppViewModel

    var body: some View {
        Menu {
            Toggle("Word Wrap", isOn: $appVM.editorVM.wordWrap)
            Toggle("Line Numbers", isOn: $appVM.editorVM.lineNumbers)
        } label: {
            Image(systemName: "slider.horizontal.3")
                .frame(width: 28, height: 28)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
    }
}
