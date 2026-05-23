import Foundation
import SwiftUI

enum ProcessingMode: String, CaseIterable, Identifiable {
    case visible
    case all

    var id: String { rawValue }
    var cliSubcommand: String { rawValue }

    var displayName: String {
        switch self {
        case .visible: return "Visible"
        case .all: return "All"
        }
    }

    var summary: String {
        switch self {
        case .visible:
            return "Removes the visible Gemini sparkle and metadata. Fast, CPU-only."
        case .all:
            return "Visible + invisible (diffusion) + metadata. First use downloads a 2 GB model."
        }
    }
}

@MainActor
@Observable
final class WatermarkService {
    static let outputSuffix = "-unwatermarked"

    private let cliPath: URL
    private let mode: () -> ProcessingMode
    private let onUpdate: () -> Void
    private var queue: [ImageJob] = []
    private var isRunning = false

    init(
        cliPath: URL,
        mode: @escaping () -> ProcessingMode,
        onUpdate: @escaping () -> Void
    ) {
        self.cliPath = cliPath
        self.mode = mode
        self.onUpdate = onUpdate
    }

    func enqueue(_ jobs: [ImageJob]) {
        queue.append(contentsOf: jobs)
        Task { await runLoop() }
    }

    private func runLoop() async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }

        while !queue.isEmpty {
            let job = queue.removeFirst()
            await process(job)
        }
    }

    private func process(_ job: ImageJob) async {
        job.status = .processing
        job.startedAt = Date()
        onUpdate()

        let output = uniqueOutputURL(for: job.source)
        let chosenMode = mode()

        var args = [chosenMode.cliSubcommand, job.source.path, "-o", output.path]
        // --device only exists on the diffusion-backed subcommands (all / invisible).
        if chosenMode == .all && CLIProbe.isAppleSilicon {
            args.append(contentsOf: ["--device", "mps"])
        }

        do {
            _ = try await CLIRunner.run(executable: cliPath, arguments: args)
            job.output = output
            job.status = .done
        } catch let error as CLIError {
            job.status = .failed(error.errorDescription ?? "Failed")
        } catch {
            job.status = .failed(error.localizedDescription)
        }
        job.finishedAt = Date()
        onUpdate()
    }

    /// Builds `<stem>-unwatermarked.<ext>` next to the source.
    /// If that file already exists, appends ` 2`, ` 3`, … before the extension.
    private func uniqueOutputURL(for source: URL) -> URL {
        let dir = source.deletingLastPathComponent()
        let ext = source.pathExtension
        let stem = source.deletingPathExtension().lastPathComponent
        let base = "\(stem)\(Self.outputSuffix)"

        var candidate = dir.appendingPathComponent(base).appendingPathExtension(ext)
        var counter = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = dir
                .appendingPathComponent("\(base) \(counter)")
                .appendingPathExtension(ext)
            counter += 1
        }
        return candidate
    }
}
