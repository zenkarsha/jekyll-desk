import SwiftUI
import WebKit

struct PreviewWebView: View {
    @ObservedObject var appVM: AppViewModel
    @State private var urlText = ""
    @State private var webViewURLText = ""
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var goBackRequestID = UUID()
    @State private var goForwardRequestID = UUID()
    @State private var animatesProgressIcon = false
    @State private var isWaitingForPreviewHTMLLoad = false
    @State private var hasPendingPreviewUpdate = false
    @State private var wasPreviewBuildInProgress = false

    var body: some View {
        VStack(spacing: 0) {
            header
            ZStack {
                bodyView
                if hasPendingPreviewUpdate {
                    pendingPreviewUpdateOverlay
                }
                if showsPreviewProgressOverlay {
                    previewProgressOverlay
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, -4)
            Divider()
            bottomStatus
        }
        .background(Color.panelBackground)
        .onAppear {
            appVM.syncPreviewURL()
            syncPreviewURL()
        }
        .onChange(of: appVM.projectVM.selectedProject?.id) { _, _ in
            appVM.syncPreviewURL()
            syncPreviewURL()
        }
        .onChange(of: appVM.serverVM.state) { _, _ in
            appVM.syncPreviewURL()
            syncPreviewURL()
        }
        .onChange(of: appVM.previewURLString) { _, _ in
            syncPreviewURL()
        }
        .onChange(of: appVM.editorVM.filepath) { _, _ in
            appVM.syncPreviewURL()
            syncPreviewURL()
        }
        .onChange(of: appVM.previewRefreshID) { _, _ in
            isWaitingForPreviewHTMLLoad = true
            hasPendingPreviewUpdate = false
            syncPreviewURL()
        }
        .onChange(of: appVM.serverVM.buildActivity) { _, activity in
            switch activity {
            case .saving, .building:
                wasPreviewBuildInProgress = true
                isWaitingForPreviewHTMLLoad = true
            case .idle:
                guard wasPreviewBuildInProgress else { return }
                wasPreviewBuildInProgress = false
                if appVM.autoRefresh {
                    hasPendingPreviewUpdate = false
                } else {
                    isWaitingForPreviewHTMLLoad = false
                    hasPendingPreviewUpdate = appVM.serverVM.state == .running
                }
            }
        }
        .onChange(of: appVM.autoRefresh) { _, enabled in
            if !enabled, isWaitingForPreviewHTMLLoad {
                isWaitingForPreviewHTMLLoad = false
                hasPendingPreviewUpdate = appVM.serverVM.state == .running && hasEditablePost
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle("PREVIEW")
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 10)

            ZStack(alignment: .bottom) {
                Divider()
                toolbar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)
            }
            .frame(height: 40)
        }
        .frame(height: 78, alignment: .top)
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            IconButton(
                systemName: "chevron.left",
                foregroundColor: canGoBack ? .primaryText : .secondaryText,
                hoverBackgroundColor: Color.black.opacity(0.06)
            ) {
                guard canGoBack else { return }
                goBackRequestID = UUID()
            }
            IconButton(
                systemName: "chevron.right",
                foregroundColor: canGoForward ? .primaryText : .secondaryText,
                hoverBackgroundColor: Color.black.opacity(0.06)
            ) {
                guard canGoForward else { return }
                goForwardRequestID = UUID()
            }
            IconButton(systemName: "arrow.clockwise", hoverBackgroundColor: Color.black.opacity(0.06)) {
                refreshPreview()
            }
            addressBar
            IconButton(systemName: "arrow.up.forward.app", iconSize: 17, hoverBackgroundColor: Color.black.opacity(0.06)) {
                if let url = URL(string: effectiveURLText) {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }

    private var addressBar: some View {
        Text(displayURLText)
            .font(.system(size: 13))
            .foregroundStyle(urlText.isEmpty ? Color.secondaryText.opacity(0.68) : Color.primaryText)
            .lineLimit(1)
            .truncationMode(.middle)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(Color.appBorder, lineWidth: 1)
            }
    }

    @ViewBuilder
    private var bodyView: some View {
        if appVM.projectVM.selectedProject == nil {
            emptyState(
                title: "No project selected",
                message: "Add a Jekyll project before starting the local server.",
                primary: "Run Jekyll Serve",
                primaryIcon: "play.fill",
                secondary: nil,
                disabled: true,
                action: {}
            )
        } else if !hasEditablePost {
            emptyState(
                title: "No post selected",
                message: "Create a markdown post to preview it.",
                primary: nil,
                primaryIcon: nil,
                secondary: nil,
                action: {}
            )
        } else {
            switch appVM.serverVM.state {
            case .stopped:
                emptyState(
                    title: "Jekyll server is not running",
                    message: "Start the local server to load the current post preview.",
                    primary: "Run Jekyll Serve",
                    primaryIcon: "play.fill",
                    secondary: nil
                ) {
                    appVM.serverVM.toggle(project: appVM.projectVM.selectedProject)
                    refreshPreview()
                }
            case .failed(let message):
                emptyState(
                    title: "Build failed",
                    message: message,
                    primary: "Retry Build",
                    primaryIcon: "arrow.clockwise",
                    secondary: nil
                ) {
                    appVM.serverVM.toggle(project: appVM.projectVM.selectedProject)
                    refreshPreview()
                }
            case .running:
                WebView(
                    url: previewURL,
                    refreshID: appVM.previewRefreshID,
                    goBackRequestID: goBackRequestID,
                    goForwardRequestID: goForwardRequestID,
                    currentURLText: $webViewURLText,
                    canGoBack: $canGoBack,
                    canGoForward: $canGoForward,
                    fallbackHTML: previewHTML,
                    onLoadFinished: {
                        isWaitingForPreviewHTMLLoad = false
                        hasPendingPreviewUpdate = false
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var bottomStatus: some View {
        HStack {
            Label(previewStatusText, systemImage: previewStatusIcon)
                .foregroundStyle(previewStatusColor)
            Spacer()
        }
        .font(.caption)
        .padding(.horizontal, 16)
        .frame(height: 30)
    }

    private var showsPreviewProgressOverlay: Bool {
        guard hasEditablePost else { return false }

        switch appVM.serverVM.buildActivity {
        case .saving, .building:
            return true

        case .idle:
            return appVM.serverVM.state == .running && isWaitingForPreviewHTMLLoad
        }
    }

    private var pendingPreviewUpdateOverlay: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.32)
                .background(Color.white.opacity(0.54))
                .contentShape(Rectangle())
                .onTapGesture {
                    refreshPreview()
                }

            VStack(spacing: 14) {
                Image(systemName: "arrow.clockwise.circle")
                    .font(.system(size: 42, weight: .semibold))

                VStack(spacing: 4) {
                    Text("Preview update available")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Click to update preview")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.secondaryText)
                }

                Button {
                    refreshPreview()
                } label: {
                    Label("Update Preview", systemImage: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .frame(width: 154, height: 34)
                        .background(Color.appBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .shadow(color: Color.appBlue.opacity(0.18), radius: 8, y: 2)
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(Color.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity)
    }

    private var previewProgressOverlay: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.32)
                .background(Color.white.opacity(0.54))
            VStack(spacing: 12) {
                Image(systemName: previewStatusIcon)
                    .font(.system(size: 34, weight: .semibold))
                    .scaleEffect(progressIconScale)
                Text(previewStatusText)
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(Color.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity)
        .onAppear {
            startProgressIconAnimation()
        }
        .onChange(of: appVM.serverVM.buildActivity) { _, activity in
            guard activity != .idle else {
                animatesProgressIcon = false
                return
            }
            startProgressIconAnimation()
        }
    }

    private var progressIconScale: CGFloat {
        animatesProgressIcon ? 1.12 : 1
    }

    private func startProgressIconAnimation() {
        animatesProgressIcon = false
        withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
            animatesProgressIcon = true
        }
    }

    private var previewStatusText: String {
        guard hasEditablePost else { return "No post selected" }

        switch appVM.serverVM.buildActivity {
        case .saving:
            return "Saving changes..."
        case .building:
            return "Building preview..."
        case .idle:
            break
        }

        switch appVM.serverVM.state {
        case .running:
            if hasPendingPreviewUpdate {
                return "Preview update available"
            }
            return "Reloaded just now"
        case .failed:
            return "Preview unavailable"
        case .stopped:
            return "Not started yet"
        }
    }

    private var previewStatusIcon: String {
        guard hasEditablePost else { return "circle" }

        switch appVM.serverVM.buildActivity {
        case .saving:
            return "square.and.arrow.down"
        case .building:
            return "arrow.clockwise"
        case .idle:
            break
        }

        switch appVM.serverVM.state {
        case .running:
            if hasPendingPreviewUpdate {
                return "arrow.clockwise.circle"
            }
            return "checkmark.circle"
        case .failed:
            return "xmark.circle"
        case .stopped:
            return "circle"
        }
    }

    private var previewStatusColor: Color {
        guard hasEditablePost else { return .secondaryText }

        switch appVM.serverVM.buildActivity {
        case .saving, .building:
            return .appBlue
        case .idle:
            break
        }

        switch appVM.serverVM.state {
        case .running:
            if hasPendingPreviewUpdate {
                return .secondaryText
            }
            return .appGreen
        case .failed:
            return .appRed
        case .stopped:
            return .secondaryText
        }
    }

    private func emptyState(
        title: String,
        message: String,
        primary: String?,
        primaryIcon: String?,
        secondary: String?,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: title == "Build failed" ? "exclamationmark.triangle" : "play.rectangle")
                .font(.system(size: 36))
                .foregroundStyle(title == "Build failed" ? Color.appRed : Color.secondaryText)
            Text(title)
                .font(.title3.weight(.semibold))
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
                .textSelection(.enabled)
            HStack {
                if let secondary {
                    Button(secondary) { appVM.showSettings = true }
                }
                if let primary, let primaryIcon {
                    Button(action: action) {
                        HStack(spacing: 9) {
                            Image(systemName: primaryIcon)
                            Text(primary)
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(disabled ? Color(red: 0.33, green: 0.37, blue: 0.44) : Color.white)
                        .frame(width: 160, height: 32)
                        .background(disabled ? Color(red: 0.875, green: 0.887, blue: 0.906) : Color.appBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .shadow(color: disabled ? Color.clear : Color.appBlue.opacity(0.18), radius: 8, y: 2)
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }

    private var previewHTML: String {
        let title = appVM.editorVM.title
        let tags = appVM.editorVM.tags.joined(separator: ", ")
        let videos = appVM.editorVM.videoIDs.filter { !$0.isEmpty }
        let embeds = videos.map { id in
            """
            <iframe src="https://www.youtube.com/embed/\(id)" title="YouTube video" allowfullscreen></iframe>
            """
        }.joined()

        return """
        <!doctype html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
        body{font-family:-apple-system,BlinkMacSystemFont,"SF Pro Text",sans-serif;margin:0;color:#111827;background:white}
        header{display:flex;align-items:center;justify-content:space-between;padding:18px 28px;border-bottom:1px solid #E5E7EB}
        nav{display:flex;gap:22px;color:#374151;font-size:14px}
        main{padding:28px;max-width:760px}
        h1{font-size:42px;line-height:1.05;margin:0 0 18px;font-weight:750}
        h2{font-size:22px;margin-top:26px}
        .meta{display:flex;gap:22px;color:#4B5563;font-size:14px;margin-bottom:22px}
        iframe{display:block;width:100%;aspect-ratio:16/9;border:0;border-radius:8px;margin:12px 0;background:#111}
        li{margin:8px 0}
        </style>
        </head>
        <body>
        <header><strong>My Jekyll Blog</strong><nav><span>Home</span><span>About</span><span>Archive</span></nav></header>
        <main>
        <h1>\(title)</h1>
        <div class="meta"><span>May 16, 2026</span><span>\(appVM.editorVM.category)</span><span>\(tags)</span></div>
        <p>Welcome to my video post! In this post, I’m sharing \(videos.count > 1 ? "two of my favorite tracks" : "one of my favorite tracks") from my playlist.</p>
        <h2>What you’ll find in this post</h2>
        <ul><li>\(videos.count > 1 ? "Two great music videos" : "One great music video")</li><li>Perfect for your playlist</li><li>Enjoy and share the vibes ♫</li></ul>
        <h2>\(videos.count > 1 ? "Videos" : "Video")</h2>
        \(embeds)
        </main>
        </body>
        </html>
        """
    }

    private func syncPreviewURL() {
        if appVM.serverVM.state == .running, hasEditablePost {
            urlText = previewURL?.absoluteString ?? (appVM.projectVM.selectedProject?.previewBaseURL ?? previewPlaceholderURL)
        } else {
            urlText = ""
        }
    }

    private var effectiveURLText: String {
        urlText.isEmpty ? previewPlaceholderURL : urlText
    }

    private var displayURLText: String {
        let text = webViewURLText.isEmpty ? effectiveURLText : webViewURLText
        return text.removingPercentEncoding ?? text
    }

    private var previewPlaceholderURL: String {
        appVM.projectVM.selectedProject?.previewBaseURL ?? "http://127.0.0.1:4000"
    }

    private var previewURL: URL? {
        appVM.previewURLString.flatMap(URL.init(string:))
    }

    private var hasEditablePost: Bool {
        appVM.editorVM.filepath != nil || !appVM.editorVM.markdownContent.isEmpty
    }

    private func refreshPreview() {
        hasPendingPreviewUpdate = false
        isWaitingForPreviewHTMLLoad = true
        appVM.reloadPreview()
    }
}

struct WebView: NSViewRepresentable {
    let url: URL?
    let refreshID: UUID
    let goBackRequestID: UUID
    let goForwardRequestID: UUID
    @Binding var currentURLText: String
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    let fallbackHTML: String
    let onLoadFinished: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> WKWebView {
        let view = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        view.navigationDelegate = context.coordinator
        removeScrollInsets(from: view)
        context.coordinator.observe(view)
        return view
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        context.coordinator.parent = self
        removeScrollInsets(from: nsView)

        if context.coordinator.lastGoBackRequestID != goBackRequestID {
            context.coordinator.lastGoBackRequestID = goBackRequestID
            if nsView.canGoBack {
                nsView.goBack()
            }
        }

        if context.coordinator.lastGoForwardRequestID != goForwardRequestID {
            context.coordinator.lastGoForwardRequestID = goForwardRequestID
            if nsView.canGoForward {
                nsView.goForward()
            }
        }

        load(nsView, coordinator: context.coordinator)
    }

    private func removeScrollInsets(from view: NSView) {
        if let scrollView = findScrollView(in: view) {
            scrollView.automaticallyAdjustsContentInsets = false
            scrollView.contentInsets = NSEdgeInsetsZero
            scrollView.scrollerInsets = NSEdgeInsetsZero
        }
    }

    private func findScrollView(in view: NSView) -> NSScrollView? {
        if let scrollView = view as? NSScrollView {
            return scrollView
        }

        for subview in view.subviews {
            if let scrollView = findScrollView(in: subview) {
                return scrollView
            }
        }

        return nil
    }

    private func load(_ view: WKWebView, coordinator: Coordinator) {
        let shouldLoad = coordinator.lastLoadedURL != url || coordinator.lastRefreshID != refreshID
        guard shouldLoad else { return }

        coordinator.resetRetryCount()
        coordinator.lastLoadedURL = url
        coordinator.lastRefreshID = refreshID

        if let url {
            let cacheBustedURL = cacheBusted(url)
            view.load(noCacheRequest(for: cacheBustedURL))
        } else {
            view.loadHTMLString(fallbackHTML, baseURL: nil)
        }
    }

    private func cacheBusted(_ url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        var items = components.queryItems?.filter { $0.name != "_jdk_refresh" } ?? []
        items.append(URLQueryItem(name: "_jdk_refresh", value: refreshID.uuidString))
        components.queryItems = items
        return components.url ?? url
    }

    private func noCacheRequest(for url: URL) -> URLRequest {
        var request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            timeoutInterval: 30
        )
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        return request
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView
        var lastLoadedURL: URL?
        var lastRefreshID: UUID?
        var lastGoBackRequestID: UUID
        var lastGoForwardRequestID: UUID
        private var observations: [NSKeyValueObservation] = []
        private var retryCount = 0
        private let maxRetryCount = 12

        init(_ parent: WebView) {
            self.parent = parent
            lastGoBackRequestID = parent.goBackRequestID
            lastGoForwardRequestID = parent.goForwardRequestID
        }

        func observe(_ webView: WKWebView) {
            observations = [
                webView.observe(\.url, options: [.new]) { [weak self] webView, _ in
                    self?.updateNavigationState(webView)
                },
                webView.observe(\.canGoBack, options: [.new]) { [weak self] webView, _ in
                    self?.updateNavigationState(webView)
                },
                webView.observe(\.canGoForward, options: [.new]) { [weak self] webView, _ in
                    self?.updateNavigationState(webView)
                }
            ]
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            retryCount = 0
            updateNavigationState(webView)

            DispatchQueue.main.async {
                self.parent.onLoadFinished()
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            retryLocalPreview(webView)
            updateNavigationState(webView)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            retryLocalPreview(webView)
            updateNavigationState(webView)
        }

        func resetRetryCount() {
            retryCount = 0
        }

        private func retryLocalPreview(_ webView: WKWebView) {
            guard
                retryCount < maxRetryCount,
                let url = lastLoadedURL
            else { return }

            retryCount += 1
            let request = parent.noCacheRequest(for: parent.cacheBusted(url))
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak webView] in
                webView?.load(request)
            }
        }

        private func updateNavigationState(_ webView: WKWebView) {
            DispatchQueue.main.async {
                self.parent.currentURLText = webView.url.map(Self.displayURLString)
                    ?? self.parent.url.map(Self.displayURLString)
                    ?? ""
                self.parent.canGoBack = webView.canGoBack
                self.parent.canGoForward = webView.canGoForward
            }
        }

        private static func displayURLString(_ url: URL) -> String {
            guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                return url.absoluteString
            }
            components.queryItems = components.queryItems?.filter { $0.name != "_jdk_refresh" }
            if components.queryItems?.isEmpty == true {
                components.queryItems = nil
            }
            let text = components.url?.absoluteString ?? url.absoluteString
            return text.removingPercentEncoding ?? text
        }
    }
}
