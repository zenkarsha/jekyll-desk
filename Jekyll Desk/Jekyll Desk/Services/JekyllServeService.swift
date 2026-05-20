import Foundation
import Darwin

final class JekyllServeService {
    private let defaultPort = 4000
    private var process: Process?
    private var pendingStopWorkItems: [ObjectIdentifier: [DispatchWorkItem]] = [:]
    private var intentionallyStoppedProcesses: Set<ObjectIdentifier> = []
    var onOutput: ((String) -> Void)?
    var onExit: ((Int32) -> Void)?

    var isRunning: Bool {
        process?.isRunning == true
    }

    func start(project: Project) throws {
        stop()

        let process = Process()
        process.currentDirectoryURL = URL(fileURLWithPath: project.path)
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lic", executableServeCommand(project.serveCommand)]
        process.environment = utf8Environment()

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async {
                self?.onOutput?(text)
            }
        }
        process.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                guard let self else { return }
                let processID = ObjectIdentifier(process)
                self.cancelPendingStopWorkItems(for: processID)
                let wasStoppedIntentionally = self.intentionallyStoppedProcesses.remove(processID) != nil
                if self.process === process {
                    self.process = nil
                }
                self.onExit?(wasStoppedIntentionally ? 0 : process.terminationStatus)
            }
        }

        try process.run()
        self.process = process
    }

    func stop() {
        guard let process, process.isRunning else {
            self.process = nil
            signalPortListeners(signal: SIGINT)
            return
        }

        let processID = ObjectIdentifier(process)
        intentionallyStoppedProcesses.insert(processID)
        cancelPendingStopWorkItems(for: processID)
        signalProcessTree(rootPID: process.processIdentifier, signal: SIGINT)
        signalPortListeners(signal: SIGINT)

        let terminateItem = DispatchWorkItem { [weak self, weak process] in
            guard let self, let process, process.isRunning else { return }
            self.signalProcessTree(rootPID: process.processIdentifier, signal: SIGTERM)
            self.signalPortListeners(signal: SIGTERM)
        }

        let killItem = DispatchWorkItem { [weak self, weak process] in
            guard let self, let process, process.isRunning else { return }
            self.signalProcessTree(rootPID: process.processIdentifier, signal: SIGKILL)
            self.signalPortListeners(signal: SIGKILL)
        }

        pendingStopWorkItems[processID] = [terminateItem, killItem]
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: terminateItem)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: killItem)
    }

    private func cancelPendingStopWorkItems(for processID: ObjectIdentifier) {
        pendingStopWorkItems.removeValue(forKey: processID)?.forEach { $0.cancel() }
    }

    private func signalProcessTree(rootPID: pid_t, signal: Int32) {
        for pid in descendantPIDs(of: rootPID).reversed() {
            kill(pid, signal)
        }
        kill(rootPID, signal)
    }

    private func descendantPIDs(of pid: pid_t) -> [pid_t] {
        let directChildren = childPIDs(of: pid)
        return directChildren + directChildren.flatMap { descendantPIDs(of: $0) }
    }

    private func childPIDs(of pid: pid_t) -> [pid_t] {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-P", String(pid)]
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return []
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [] }
        return output
            .split(whereSeparator: \.isNewline)
            .compactMap { pid_t($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }

    private func signalPortListeners(signal: Int32) {
        for pid in listenerPIDs() {
            guard pid != getpid() else { continue }
            kill(pid, signal)
        }
    }

    private func listenerPIDs() -> [pid_t] {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["-tiTCP:\(defaultPort)", "-sTCP:LISTEN"]
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return []
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [] }
        return output
            .split(whereSeparator: \.isNewline)
            .compactMap { pid_t($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }

    private func sanitizedServeCommand(_ command: String) -> String {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        let command = trimmed.isEmpty ? "bundle exec jekyll serve" : trimmed

        let sanitized = command
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .withoutLiveReloadOptions
            .withoutPortOptions

        return "\(sanitized) --port \(defaultPort)"
    }

    private func executableServeCommand(_ command: String) -> String {
        let command = sanitizedServeCommand(command)
        let environmentAssignmentPattern = #"^((?:[A-Za-z_][A-Za-z0-9_]*=(?:"[^"]*"|'[^']*'|\S+)\s+)+)(.+)$"#

        guard
            let regex = try? NSRegularExpression(pattern: environmentAssignmentPattern),
            let match = regex.firstMatch(in: command, range: NSRange(command.startIndex..<command.endIndex, in: command)),
            let assignmentsRange = Range(match.range(at: 1), in: command),
            let commandRange = Range(match.range(at: 2), in: command)
        else {
            return "exec \(command)"
        }

        return "exec env \(command[assignmentsRange])\(command[commandRange])"
    }

    private func utf8Environment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["LANG"] = "en_US.UTF-8"
        environment["LC_ALL"] = "en_US.UTF-8"
        environment["LC_CTYPE"] = "en_US.UTF-8"
        return environment
    }
}

private extension String {
    var withoutLiveReloadOptions: String {
        replacing(#"(?<!\S)-l(?!\S)"#, with: "")
            .replacing(#"(?<!\S)--livereload(?!\S)"#, with: "")
            .replacing(#"(?<!\S)--livereload-(?:ignore|min-delay|max-delay|port)(?:[=\s]+(?:"[^"]*"|'[^']*'|\S+))?"#, with: "")
            .replacing(#"\s+"#, with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var withoutPortOptions: String {
        replacing(#"(?<!\S)--port(?:[=\s]+(?:"[^"]*"|'[^']*'|\S+))?"#, with: "")
            .replacing(#"(?<!\S)-P(?:\s+(?:"[^"]*"|'[^']*'|\S+))?"#, with: "")
            .replacing(#"\s+"#, with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func replacing(_ pattern: String, with replacement: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return self }
        let range = NSRange(startIndex..<endIndex, in: self)
        return regex.stringByReplacingMatches(in: self, range: range, withTemplate: replacement)
    }
}
