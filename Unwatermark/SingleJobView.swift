import SwiftUI
import AppKit

/// Display for the single-image case. While the job is pending or processing,
/// shows a centered placeholder. When done, shows a draggable before/after
/// comparison. On failure, shows the error.
struct SingleJobView: View {
    @Environment(AppState.self) private var app
    let job: ImageJob

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: statusIcon)
                .foregroundStyle(statusColor)
            Text(job.displayName)
                .font(.callout.weight(.medium))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private var trailing: some View {
        switch job.status {
        case .done:
            if let output = job.output {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([output])
                } label: {
                    Label("Reveal", systemImage: "folder")
                        .labelStyle(.titleAndIcon)
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            clearButton
        case .failed:
            clearButton
        default:
            EmptyView()
        }
    }

    private var clearButton: some View {
        Button {
            withAnimation(Theme.smoothEase) { app.clearFinished() }
        } label: {
            Text("Clear")
                .font(.caption)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var content: some View {
        switch job.status {
        case .pending:
            placeholderCard {
                Image(systemName: "clock")
                    .font(.system(size: 30))
                    .foregroundStyle(.secondary)
                Text("Queued")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        case .processing:
            placeholderCard {
                Image(systemName: "sparkles")
                    .font(.system(size: 32))
                    .foregroundStyle(Theme.accentGradient)
                    .symbolEffect(.variableColor.iterative.reversing)
                Text("Cleaning your image…")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                ProgressView()
                    .progressViewStyle(.linear)
                    .frame(maxWidth: 220)
            }
        case .done:
            if let output = job.output {
                let fm = FileManager.default
                let sourceMissing = !fm.fileExists(atPath: job.source.path)
                let outputMissing = !fm.fileExists(atPath: output.path)
                if sourceMissing || outputMissing {
                    placeholderCard {
                        Image(systemName: "doc.questionmark")
                            .font(.system(size: 30))
                            .foregroundStyle(.orange)
                        Text(missingFilesMessage(sourceMissing: sourceMissing, outputMissing: outputMissing))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                } else {
                    BeforeAfterView(beforeURL: job.source, afterURL: output)
                }
            } else {
                placeholderCard {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.green)
                    Text("Done")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        case .failed(let msg):
            placeholderCard {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.red)
                Text(msg)
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 24)
            }
        }
    }

    private func placeholderCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 10) { content() }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .fill(Color.secondary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(0.12), lineWidth: 1)
            )
    }

    private func missingFilesMessage(sourceMissing: Bool, outputMissing: Bool) -> String {
        switch (sourceMissing, outputMissing) {
        case (true, true): return "Both the original and the cleaned image have been moved or deleted. Preview is no longer available."
        case (true, false): return "The original image has been moved or deleted. Before/after preview is no longer available."
        case (false, true): return "The cleaned image has been moved or deleted. Before/after preview is no longer available."
        case (false, false): return ""
        }
    }

    private var statusIcon: String {
        switch job.status {
        case .pending: return "clock"
        case .processing: return "sparkles"
        case .done: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }

    private var statusColor: Color {
        switch job.status {
        case .done: return .green
        case .failed: return .red
        case .processing: return .accentColor
        case .pending: return .secondary
        }
    }
}
