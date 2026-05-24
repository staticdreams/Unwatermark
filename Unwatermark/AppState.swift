import Foundation
import SwiftUI

@MainActor
@Observable
final class AppState {
    enum Phase: Equatable {
        case probing
        case needsSetup
        case ready
    }

    private static let cliPathKey = "cliPath"
    private static let modeKey = "processingMode"
    private static let warnedAllModeKey = "warnedAllMode"

    var phase: Phase = .probing
    var cliPath: URL?
    var mode: ProcessingMode {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: Self.modeKey) }
    }
    var jobs: [ImageJob] = []
    /// User-selected history entry to preview. When nil, the preview follows
    /// the most recently added job.
    var selectedJobID: UUID?
    /// URLs received from Dock drops or "Open With" before the CLI was ready.
    /// Drained inside `probe()` / `reprobe()` once `phase` becomes `.ready`.
    private var pendingExternalURLs: [URL] = []
    var hasWarnedAllMode: Bool {
        didSet { UserDefaults.standard.set(hasWarnedAllMode, forKey: Self.warnedAllModeKey) }
    }

    /// The job currently shown in the preview area. Resolves the user's
    /// explicit selection if still present, otherwise falls back to the last
    /// added job. Returns nil only when there are no jobs.
    var selectedJob: ImageJob? {
        if let id = selectedJobID, let job = jobs.first(where: { $0.id == id }) {
            return job
        }
        return jobs.last
    }

    /// ID used by the history list to render the selection highlight. Includes
    /// the implicit fallback so the "latest" row visibly lights up.
    var effectiveSelectedJobID: UUID? { selectedJob?.id }

    private(set) var service: WatermarkService?

    init() {
        let defaults = UserDefaults.standard
        if let raw = defaults.string(forKey: Self.modeKey),
           let m = ProcessingMode(rawValue: raw) {
            self.mode = m
        } else {
            self.mode = .visible
        }
        self.hasWarnedAllMode = defaults.bool(forKey: Self.warnedAllModeKey)
    }

    func probe() async {
        phase = .probing
        // Trust a remembered path if it still exists.
        if let cached = UserDefaults.standard.string(forKey: Self.cliPathKey) {
            let url = URL(fileURLWithPath: cached)
            if FileManager.default.isExecutableFile(atPath: url.path) {
                adoptCLI(at: url)
                phase = .ready
                drainPendingExternalURLs()
                return
            }
        }

        if let found = CLIProbe.findExecutable(named: "remove-ai-watermarks") {
            adoptCLI(at: found)
            phase = .ready
            drainPendingExternalURLs()
        } else {
            phase = .needsSetup
        }
    }

    func reprobe() async {
        if let found = CLIProbe.findExecutable(named: "remove-ai-watermarks") {
            adoptCLI(at: found)
            phase = .ready
            drainPendingExternalURLs()
        }
    }

    private func adoptCLI(at url: URL) {
        cliPath = url
        UserDefaults.standard.set(url.path, forKey: Self.cliPathKey)
        service = WatermarkService(
            cliPath: url,
            mode: { [weak self] in self?.mode ?? .visible },
            onUpdate: { [weak self] in
                // Triggers Observation re-render by mutating the jobs array reference.
                guard let self else { return }
                self.jobs = self.jobs
            }
        )
    }

    func enqueue(_ urls: [URL]) {
        let new = urls.map(ImageJob.init(source:))
        // New drop → follow the latest until the user picks something else.
        selectedJobID = nil
        jobs.append(contentsOf: new)
        service?.enqueue(new)
    }

    /// Entry point for Dock drops and "Open With…" — filters to images we
    /// support, then enqueues immediately or buffers until the CLI is ready.
    func handleExternalOpen(urls: [URL]) {
        let images = urls.filter(Self.isAcceptableImage)
        guard !images.isEmpty else { return }
        if phase == .ready {
            enqueue(images)
        } else {
            pendingExternalURLs.append(contentsOf: images)
        }
    }

    private func drainPendingExternalURLs() {
        guard !pendingExternalURLs.isEmpty else { return }
        let urls = pendingExternalURLs
        pendingExternalURLs.removeAll()
        enqueue(urls)
    }

    private static let imageExtensions: Set<String> = [
        "png", "jpg", "jpeg", "webp", "tif", "tiff", "heic", "bmp"
    ]

    private static func isAcceptableImage(_ url: URL) -> Bool {
        imageExtensions.contains(url.pathExtension.lowercased())
    }

    func select(_ job: ImageJob) {
        selectedJobID = job.id
    }

    func clearFinished() {
        jobs.removeAll { job in
            if case .done = job.status { return true }
            if case .failed = job.status { return true }
            return false
        }
        selectedJobID = nil
    }
}
