import Foundation

enum JekyllBuildError: LocalizedError {
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .failed(let message):
            return message
        }
    }
}

final class JekyllBuildService: @unchecked Sendable {
    private var process: Process?

    func build(project: Project) async throws -> String {
        let process = Process()
        let output = Pipe()

        process.currentDirectoryURL = URL(fileURLWithPath: project.path)
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lic", "bundle exec jekyll build"]
        process.environment = utf8Environment()
        process.standardOutput = output
        process.standardError = output

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.process = process
                let collectedOutput = BuildOutputBuffer()

                output.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    guard !data.isEmpty else { return }
                    collectedOutput.append(data)
                }

                process.terminationHandler = { [weak self] process in
                    output.fileHandleForReading.readabilityHandler = nil
                    let remaining = output.fileHandleForReading.readDataToEndOfFile()
                    if !remaining.isEmpty {
                        collectedOutput.append(remaining)
                    }

                    DispatchQueue.main.async {
                        if self?.process === process {
                            self?.process = nil
                        }

                        let text = collectedOutput.stringValue
                        if process.terminationStatus == 0 {
                            continuation.resume(returning: text)
                        } else {
                            continuation.resume(throwing: JekyllBuildError.failed(text))
                        }
                    }
                }

                do {
                    try process.run()
                } catch {
                    output.fileHandleForReading.readabilityHandler = nil
                    self.process = nil
                    continuation.resume(throwing: error)
                }
            }
        } onCancel: {
            process.terminate()
        }
    }

    private func utf8Environment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["LANG"] = "en_US.UTF-8"
        environment["LC_ALL"] = "en_US.UTF-8"
        environment["LC_CTYPE"] = "en_US.UTF-8"
        return environment
    }
}

private final class BuildOutputBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    var stringValue: String {
        lock.lock()
        defer { lock.unlock() }
        return String(data: data, encoding: .utf8) ?? ""
    }

    func append(_ newData: Data) {
        lock.lock()
        defer { lock.unlock() }
        data.append(newData)
    }
}
