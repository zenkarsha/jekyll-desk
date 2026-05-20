import SwiftUI

struct StatusBarView: View {
    @ObservedObject var appVM: AppViewModel

    var body: some View {
        HStack(spacing: 24) {
            HStack(spacing: 8) {
                StatusDot(color: appVM.serverVM.state == .running ? .appGreen : .secondaryText)
                Text("Jekyll server: \(appVM.serverVM.state == .running ? "running" : "stopped")")
            }
            Divider().frame(height: 20)
            if let lastBuild = appVM.serverVM.lastBuild {
                Label("Last build: \(lastBuild)", systemImage: lastBuildIcon)
                    .foregroundStyle(lastBuildColor)
                if let lastBuildDate = appVM.serverVM.lastBuildDate {
                    Text(Self.timeFormatter.string(from: lastBuildDate))
                        .foregroundStyle(.secondary)
                }
            } else {
                Label("Build not run yet", systemImage: "minus.circle")
                    .foregroundStyle(Color.secondaryText)
            }
            Divider().frame(height: 20)
            Label(watchingStatusText, systemImage: "arrow.triangle.2.circlepath")
                .foregroundStyle(isWatchingForChanges ? Color.appBlue : Color.secondaryText)
            Divider().frame(height: 20)
            Label(appVM.autoRefresh ? "Auto-reload active" : "Auto-reload off", systemImage: "bolt")
                .foregroundStyle(appVM.autoRefresh ? Color.appBlue : Color.secondary)
            Spacer()
            Button {
                appVM.showSettings.toggle()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(appVM.showSettings ? Color.appBlue : Color.primaryText)
                    .frame(width: 28, height: 28)
                    .background(appVM.showSettings ? Color.selectionBlue : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .buttonStyle(.borderless)
            .help("Settings")
        }
        .font(.caption)
        .padding(.horizontal, 18)
        .background(Color.appBackground)
    }

    private var lastBuildIcon: String {
        appVM.serverVM.lastBuild == "success" ? "checkmark.circle" : "xmark.circle"
    }

    private var lastBuildColor: Color {
        appVM.serverVM.lastBuild == "success" ? Color.appGreen : Color.appRed
    }

    private var isWatchingForChanges: Bool {
        appVM.serverVM.state == .running && appVM.editorVM.lastSavedURL != nil
    }

    private var watchingStatusText: String {
        isWatchingForChanges ? "Watching for changes" : "Not watching"
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter
    }()
}
