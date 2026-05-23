import Foundation

struct CLIResult {
    let exitCode: Int32
    let combinedOutput: String
}

enum CLIError: LocalizedError {
    case nonZeroExit(code: Int32, output: String)
    case launchFailed(String)

    var errorDescription: String? {
        switch self {
        case .nonZeroExit(let code, let output):
            let trimmed = output.split(separator: "\n").last.map(String.init) ?? "exit \(code)"
            return trimmed.isEmpty ? "Exit code \(code)" : trimmed
        case .launchFailed(let msg):
            return msg
        }
    }
}

enum CLIRunner {
    /// Streams merged stdout/stderr line-by-line as the process runs.
    /// The continuation finishes when the process exits; non-zero exit throws.
    static func stream(executable: URL, arguments: [String]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let process = Process()
            process.executableURL = executable
            process.arguments = arguments

            var env = ProcessInfo.processInfo.environment
            env["PATH"] = CLIProbe.augmentedPATH
            env["HOME"] = FileManager.default.homeDirectoryForCurrentUser.path
            process.environment = env

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            var buffer = Data()
            let handle = pipe.fileHandleForReading
            handle.readabilityHandler = { fh in
                let chunk = fh.availableData
                guard !chunk.isEmpty else { return }
                buffer.append(chunk)
                while let nl = buffer.firstIndex(of: 0x0A) {
                    let lineData = buffer.subdata(in: 0..<nl)
                    buffer.removeSubrange(0...nl)
                    if let line = String(data: lineData, encoding: .utf8) {
                        continuation.yield(line)
                    }
                }
            }

            process.terminationHandler = { proc in
                handle.readabilityHandler = nil
                if !buffer.isEmpty, let tail = String(data: buffer, encoding: .utf8), !tail.isEmpty {
                    continuation.yield(tail)
                }
                if proc.terminationStatus == 0 {
                    continuation.finish()
                } else {
                    continuation.finish(throwing: CLIError.nonZeroExit(
                        code: proc.terminationStatus,
                        output: ""
                    ))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.finish(throwing: CLIError.launchFailed(error.localizedDescription))
            }

            continuation.onTermination = { _ in
                if process.isRunning { process.terminate() }
            }
        }
    }

    /// Runs to completion and returns merged output + exit code.
    @discardableResult
    static func run(executable: URL, arguments: [String]) async throws -> CLIResult {
        var collected = ""
        do {
            for try await line in stream(executable: executable, arguments: arguments) {
                collected += line + "\n"
            }
            return CLIResult(exitCode: 0, combinedOutput: collected)
        } catch CLIError.nonZeroExit(let code, _) {
            throw CLIError.nonZeroExit(code: code, output: collected)
        }
    }
}
