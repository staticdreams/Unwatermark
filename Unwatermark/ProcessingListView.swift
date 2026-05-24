import SwiftUI
import AppKit

struct ProcessingListView: View {
    @Environment(AppState.self) private var app
    /// When non-nil, renders this list instead of `app.jobs`.
    var jobs: [ImageJob]? = nil
    /// When true, rows highlight the currently-selected job and tap to select.
    var selectable: Bool = false

    private var displayJobs: [ImageJob] { jobs ?? app.jobs }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(displayJobs) { job in
                    JobRow(
                        job: job,
                        isSelected: selectable && app.effectiveSelectedJobID == job.id,
                        onTap: selectable ? { app.select(job) } : nil
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity
                    ))
                }
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
        }
        .animation(Theme.smoothEase, value: displayJobs.count)
    }
}

private struct JobRow: View {
    let job: ImageJob
    var isSelected: Bool = false
    var onTap: (() -> Void)? = nil
    @State private var thumb: NSImage?
    @State private var shake: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
            VStack(alignment: .leading, spacing: 3) {
                Text(job.displayName)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                statusView
            }
            Spacer(minLength: 0)
            trailingAccessory
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .fill(backgroundFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .strokeBorder(borderColor, lineWidth: isSelected ? 1.5 : 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
        .offset(x: shake ? -3 : 0)
        .onChange(of: job.status) { _, newStatus in
            if case .failed = newStatus {
                triggerShake()
            }
        }
        .task(id: job.source) {
            await loadThumb()
        }
        .animation(Theme.smoothEase, value: isSelected)
    }

    private var backgroundFill: Color {
        isSelected ? Color.accentColor.opacity(0.14) : Color.secondary.opacity(0.06)
    }

    private var borderColor: Color {
        if isSelected { return Color.accentColor.opacity(0.65) }
        switch job.status {
        case .done: return Color.green.opacity(0.5)
        case .failed: return Color.red.opacity(0.5)
        default: return Color.clear
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.secondary.opacity(0.15))
            if let thumb {
                Image(nsImage: thumb)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            if case .processing = job.status {
                ShimmerOverlay()
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .frame(width: 46, height: 46)
    }

    @ViewBuilder
    private var statusView: some View {
        switch job.status {
        case .pending:
            Text("Queued")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .processing:
            HStack(spacing: 6) {
                ProgressView()
                    .progressViewStyle(.linear)
                    .frame(maxWidth: 140)
                Text("Cleaning…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .done:
            if let output = job.output {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([output])
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "folder")
                        Text("Show in Finder")
                    }
                    .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            } else {
                Text("Done")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .failed(let msg):
            Text(msg)
                .font(.caption)
                .foregroundStyle(.red.opacity(0.85))
                .lineLimit(2)
        }
    }

    @ViewBuilder
    private var trailingAccessory: some View {
        switch job.status {
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.title3)
                .transition(.scale.combined(with: .opacity))
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .font(.title3)
        case .processing:
            Image(systemName: "sparkles")
                .foregroundStyle(Theme.accentGradient)
                .font(.title3)
                .symbolEffect(.variableColor.iterative.reversing)
        case .pending:
            Image(systemName: "clock")
                .foregroundStyle(.secondary)
        }
    }

    private func triggerShake() {
        withAnimation(.linear(duration: 0.05).repeatCount(6, autoreverses: true)) {
            shake = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            shake = false
        }
    }

    private func loadThumb() async {
        let url = job.source
        let image: NSImage? = await Task.detached(priority: .utility) {
            guard let src = NSImage(contentsOf: url) else { return nil }
            let target = NSSize(width: 92, height: 92)
            let resized = NSImage(size: target)
            resized.lockFocus()
            src.draw(in: NSRect(origin: .zero, size: target),
                     from: .zero,
                     operation: .copy,
                     fraction: 1.0)
            resized.unlockFocus()
            return resized
        }.value
        await MainActor.run { self.thumb = image }
    }
}

private struct ShimmerOverlay: View {
    @State private var phase: CGFloat = -1

    var body: some View {
        GeometryReader { geo in
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.white.opacity(0.0),
                    Color.white.opacity(0.35),
                    Color.white.opacity(0.0)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: geo.size.width * 0.5)
            .offset(x: phase * geo.size.width * 1.5)
            .blendMode(.plusLighter)
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
        }
    }
}
