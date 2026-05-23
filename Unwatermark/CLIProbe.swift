import Foundation

enum CLIProbe {
    /// Search locations beyond the inherited (often missing) PATH for GUI-launched apps.
    static let searchPaths: [String] = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(home)/.local/bin",
            "\(home)/.local/share/uv/tools/remove-ai-watermarks/bin",
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin"
        ]
    }()

    static func findExecutable(named name: String) -> URL? {
        let fm = FileManager.default

        // Try PATH first if it happens to be populated.
        if let pathEnv = ProcessInfo.processInfo.environment["PATH"] {
            for dir in pathEnv.split(separator: ":") {
                let candidate = URL(fileURLWithPath: String(dir)).appendingPathComponent(name)
                if fm.isExecutableFile(atPath: candidate.path) {
                    return candidate
                }
            }
        }

        for dir in searchPaths {
            let candidate = URL(fileURLWithPath: dir).appendingPathComponent(name)
            if fm.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }

    static var isAppleSilicon: Bool {
        #if arch(arm64)
        return true
        #else
        return false
        #endif
    }

    /// PATH string suitable for handing to child processes so `uv tool install`
    /// can locate `python`, and so installed entry points can find their venv.
    static var augmentedPATH: String {
        let existing = ProcessInfo.processInfo.environment["PATH"] ?? ""
        let extras = searchPaths.joined(separator: ":")
        return existing.isEmpty ? extras : "\(extras):\(existing)"
    }
}
