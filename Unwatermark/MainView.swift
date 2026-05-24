import SwiftUI

struct MainView: View {
    @Environment(AppState.self) private var app
    @State private var showAllModeSheet = false

    var body: some View {
        @Bindable var app = app

        VStack(spacing: 16) {
            header
            HStack(spacing: 16) {
                DropZoneView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                HistorySidebar()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: 220)
            PreviewArea()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(20)
        .background(.background)
        .animation(Theme.smoothEase, value: app.jobs.count)
        .sheet(isPresented: $showAllModeSheet) {
            AllModeWarningSheet(
                isPresented: $showAllModeSheet,
                onConfirm: {
                    app.mode = .all
                    app.hasWarnedAllMode = true
                },
                onCancel: {
                    // Snap segmented control back to visible visually.
                    app.mode = .visible
                }
            )
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.title3)
                .foregroundStyle(Theme.accentGradient)
            Text("Unwatermark")
                .font(.title3.weight(.semibold))
            Spacer()
            modePicker
        }
    }

    private var modePicker: some View {
        Picker("Mode", selection: Binding(
            get: { app.mode },
            set: { newMode in
                if newMode == .all && !app.hasWarnedAllMode {
                    // Briefly accept then show sheet; sheet's cancel reverts.
                    app.mode = newMode
                    showAllModeSheet = true
                } else {
                    app.mode = newMode
                }
            }
        )) {
            ForEach(ProcessingMode.allCases) { mode in
                Text(mode.displayName).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 180)
        .help(app.mode.summary)
    }
}

/// History list rendered next to the drop zone. Selecting a row puts that job
/// in the preview area below; newly enqueued jobs auto-follow as the preview.
private struct HistorySidebar: View {
    @Environment(AppState.self) private var app

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if app.jobs.isEmpty {
                emptyState
            } else {
                ProcessingListView(jobs: app.jobs.reversed(), selectable: true)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .fill(Color.secondary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.12), lineWidth: 1)
        )
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text("History")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.secondary)
            if !app.jobs.isEmpty {
                Text("·").foregroundStyle(.tertiary)
                Text("\(app.jobs.count)")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            }
            if inFlightCount > 0 {
                ProgressView()
                    .controlSize(.small)
                    .padding(.leading, 4)
            }
            Spacer(minLength: 8)
            if hasFinished {
                Button {
                    withAnimation(Theme.smoothEase) { app.clearFinished() }
                } label: {
                    Text("Clear finished")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo.stack")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text("No images yet")
                .font(.callout)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var inFlightCount: Int {
        app.jobs.reduce(0) { acc, job in
            switch job.status {
            case .pending, .processing: return acc + 1
            default: return acc
            }
        }
    }

    private var hasFinished: Bool {
        app.jobs.contains { job in
            if case .done = job.status { return true }
            if case .failed = job.status { return true }
            return false
        }
    }
}

/// Always-present preview area below the drop zone + history. Shows the
/// currently-selected job's before/after compare, or an empty placeholder.
private struct PreviewArea: View {
    @Environment(AppState.self) private var app

    var body: some View {
        if let job = app.selectedJob {
            SingleJobView(job: job)
                .id(job.id) // remount when the user picks a different job
                .transition(.opacity)
        } else {
            emptyState
                .transition(.opacity)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "rectangle.on.rectangle.slash")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text("Drop an image to preview the before/after here")
                .font(.callout)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .fill(Color.secondary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.10), lineWidth: 1)
        )
    }
}

private struct AllModeWarningSheet: View {
    @Binding var isPresented: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "icloud.and.arrow.down")
                .font(.system(size: 36))
                .foregroundStyle(Theme.accentGradient)
            Text("Switch to “All” mode?")
                .font(.title3.weight(.semibold))
            Text("This mode also removes invisible diffusion watermarks. The first time you clean an image, a ~2 GB model is downloaded and cached.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)
            HStack(spacing: 10) {
                Button("Stay on Visible") {
                    onCancel()
                    isPresented = false
                }
                Button("Use All Mode") {
                    onConfirm()
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 4)
        }
        .padding(28)
        .frame(width: 380)
    }
}
