import Foundation

enum ServerState: Equatable {
    case stopped
    case running
    case failed(String)

    var label: String {
        switch self {
        case .stopped: "Not running"
        case .running: "Running"
        case .failed: "Build failed"
        }
    }
}

enum BuildActivity: Equatable {
    case idle
    case saving
    case building
}

@MainActor
final class JekyllServerViewModel: ObservableObject {
    @Published var state: ServerState = .stopped
    @Published var log: String = ""
    @Published var lastBuild: String?
    @Published var lastBuildDate: Date?
    @Published var buildVersion = UUID()
    @Published var buildActivity: BuildActivity = .idle

    private let service = JekyllServeService()

    var statusLabel: String {
        switch state {
        case .stopped:
            return "Not running"
        case .running:
            return "Running on 127.0.0.1:4000"
        case .failed:
            return "Build failed"
        }
    }

    init() {
        service.onOutput = { [weak self] output in
            guard let self else { return }
            log += output
            if Self.indicatesBuildStarted(output) {
                buildActivity = .building
            }
            if Self.indicatesServerStarted(output) {
                state = .running
                markBuildSucceeded()
                buildActivity = .idle
                buildVersion = UUID()
            } else if Self.indicatesBuildCompleted(output) {
                markBuildSucceeded()
                buildActivity = .idle
                buildVersion = UUID()
            }
        }
        service.onExit = { [weak self] status in
            guard let self else { return }
            guard status != 0 else {
                if self.service.isRunning == false {
                    state = .stopped
                }
                return
            }
            guard Self.hasDisplayableError(in: log) else {
                state = .stopped
                return
            }
            state = .failed(Self.displayError(from: log, fallbackStatus: status))
            markBuildFailed()
        }
    }

    private static func displayError(from log: String, fallbackStatus: Int32? = nil) -> String {
        let meaningfulLines = displayLines(from: log)

        if let explicitErrorIndex = meaningfulLines.lastIndex(where: isExplicitErrorLine) {
            return Array(meaningfulLines[explicitErrorIndex...])
                .prefix(8)
                .joined(separator: "\n")
        }

        let trailingLines = meaningfulLines.suffix(8)
        if !trailingLines.isEmpty {
            return trailingLines.joined(separator: "\n")
        }

        if let fallbackStatus {
            return "Jekyll serve exited with status \(fallbackStatus)."
        }

        return "Jekyll serve failed."
    }

    private static func hasDisplayableError(in log: String) -> Bool {
        displayLines(from: log).contains(where: isExplicitErrorLine)
    }

    private static func isExplicitErrorLine(_ line: String) -> Bool {
        line.localizedCaseInsensitiveContains("error:") ||
            line.localizedCaseInsensitiveContains("jekyll error") ||
            line.localizedCaseInsensitiveContains("liquid exception") ||
            line.localizedCaseInsensitiveContains("dependency error") ||
            line.localizedCaseInsensitiveContains("could not") ||
            (line.localizedCaseInsensitiveContains("failed to") && !isBundlerCommandWrapper(line)) ||
            line.localizedCaseInsensitiveContains("cannot load") ||
            line.localizedCaseInsensitiveContains("missing") ||
            line.localizedCaseInsensitiveContains("address already in use") ||
            line.localizedCaseInsensitiveContains("errno::")
    }

    private static func indicatesServerStarted(_ output: String) -> Bool {
        output.localizedCaseInsensitiveContains("Server address") ||
            output.localizedCaseInsensitiveContains("Server running") ||
            output.localizedCaseInsensitiveContains("Auto-regeneration: enabled")
    }

    private static func indicatesBuildCompleted(_ output: String) -> Bool {
        output.localizedCaseInsensitiveContains("done in ")
    }

    private static func indicatesBuildStarted(_ output: String) -> Bool {
        output.localizedCaseInsensitiveContains("Regenerating:") ||
            output.localizedCaseInsensitiveContains("Generating...")
    }

    private static func displayLines(from log: String) -> [String] {
        let lines = log
            .components(separatedBy: .newlines)
            .map { stripANSI($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return lines.filter { line in
            (!isRubyStackFrame(line) || carriesUsefulError(line)) && !isJekyllTraceHint(line)
        }
    }

    private static func stripANSI(_ text: String) -> String {
        let pattern = #"\u{001B}\[[0-9;]*m"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: "")
    }

    private static func isRubyStackFrame(_ line: String) -> Bool {
        if line == "Traceback" { return true }
        if line.hasPrefix("from "), line.contains(":in `") { return true }
        if line.contains("/bundler/"), line.contains(":in `") { return true }
        if line.contains("/ruby/gems/"), line.contains(":in `") { return true }
        if line.contains("/usr/local/bin/bundle"), line.contains(":in `") { return true }
        return false
    }

    private static func isJekyllTraceHint(_ line: String) -> Bool {
        if line.allSatisfy({ $0 == "-" || $0.isWhitespace }) { return true }
        if line.localizedCaseInsensitiveContains("please append `--trace`") { return true }
        if line.localizedCaseInsensitiveContains("for any additional information or backtrace") { return true }
        return false
    }

    private static func isBundlerCommandWrapper(_ line: String) -> Bool {
        line.localizedCaseInsensitiveContains("bundler: failed to load command")
    }

    private static func carriesUsefulError(_ line: String) -> Bool {
        line.localizedCaseInsensitiveContains("could not find") ||
            line.localizedCaseInsensitiveContains("invalid byte sequence") ||
            line.localizedCaseInsensitiveContains("syntax error") ||
            line.localizedCaseInsensitiveContains("liquid exception") ||
            line.localizedCaseInsensitiveContains("dependency error") ||
            line.localizedCaseInsensitiveContains("cannot load")
    }

    func toggle(project: Project?) {
        if state == .running {
            stop()
        } else {
            start(project: project)
        }
    }

    func start(project: Project?) {
        guard let project, state != .running else { return }
        do {
            log = ""
            try service.start(project: project)
            state = .running
            buildActivity = .building
        } catch {
            state = .failed(error.localizedDescription)
            buildActivity = .idle
            markBuildFailed()
        }
    }

    func stop() {
        service.stop()
        state = .stopped
        buildActivity = .idle
    }

    func resetForProjectChange() {
        stop()
        log = ""
        lastBuild = nil
        lastBuildDate = nil
    }

    func markSaving() {
        guard state == .running else { return }
        buildActivity = .saving
    }

    func markBuildPending() {
        guard state == .running else { return }
        buildActivity = .building
    }

    func finishExplicitBuild(output: String) {
        log += output
        state = .running
        markBuildSucceeded()
        buildActivity = .idle
        buildVersion = UUID()
    }

    func failExplicitBuild(_ message: String) {
        log += "\n\(message)"
        state = .failed(Self.displayError(from: message))
        markBuildFailed()
        buildActivity = .idle
    }

    private func markBuildSucceeded() {
        lastBuild = "success"
        lastBuildDate = Date()
    }

    private func markBuildFailed() {
        lastBuild = "failed"
        lastBuildDate = Date()
    }
}
