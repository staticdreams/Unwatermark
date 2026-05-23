import SwiftUI

private enum InstallerChoice: String, CaseIterable, Identifiable {
    case uv
    case pipx

    var id: String { rawValue }
    var displayName: String { rawValue }

    var binaryName: String { rawValue }

    var installInstruction: String {
        switch self {
        case .uv: return "uv tool install …"
        case .pipx: return "pipx install …"
        }
    }
}

@MainActor
@Observable
private final class SetupModel {
    enum Phase: Equatable {
        case idle
        case installingBootstrap
        case installingTool
        case verifying
        case done
        case failed(String)
    }

    var phase: Phase = .idle
    var choice: InstallerChoice = .uv
    var logLines: [String] = []
    var isRunning: Bool {
        switch phase {
        case .idle, .done, .failed: return false
        default: return true
        }
    }

    func reset() {
        phase = .idle
        logLines.removeAll()
    }

    func log(_ line: String) {
        logLines.append(line)
        if logLines.count > 400 {
            logLines.removeFirst(logLines.count - 400)
        }
    }
}

struct SetupView: View {
    @Environment(AppState.self) private var app
    @State private var model = SetupModel()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.2)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            footer
        }
        .background(.background)
    }

    private var header: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Theme.dimGradient)
                    .frame(width: 64, height: 64)
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(Theme.accentGradient)
            }
            Text("Set up Unwatermark")
                .font(.title2.weight(.semibold))
            Text("Unwatermark uses a small open-source command-line tool to clean your images. Install it once and you're done.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 32)
        .padding(.bottom, 20)
    }

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 14) {
            installerPicker
            logPane
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 8)
    }

    private var installerPicker: some View {
        HStack(spacing: 12) {
            ForEach(InstallerChoice.allCases) { choice in
                Button {
                    model.choice = choice
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: model.choice == choice ? "largecircle.fill.circle" : "circle")
                        Text("Install with \(choice.displayName)")
                            .font(.callout.weight(.medium))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(model.choice == choice ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(model.choice == choice ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(model.isRunning)
            }
            Spacer()
        }
    }

    private var logPane: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    if model.logLines.isEmpty {
                        Text(emptyLogHint)
                            .font(.system(.callout, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    ForEach(Array(model.logLines.enumerated()), id: \.offset) { idx, line in
                        Text(line)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(idx)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(12)
            }
            .background(
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .fill(Color.secondary.opacity(0.08))
            )
            .frame(maxHeight: .infinity)
            .onChange(of: model.logLines.count) { _, _ in
                withAnimation(.linear(duration: 0.1)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }

    private var emptyLogHint: String {
        switch model.choice {
        case .uv:
            return "Click Install to:\n  1. Install uv (if needed) from astral.sh\n  2. uv tool install git+https://github.com/wiltodelta/remove-ai-watermarks.git"
        case .pipx:
            return "Click Install to:\n  1. Verify pipx is available\n  2. pipx install git+https://github.com/wiltodelta/remove-ai-watermarks.git"
        }
    }

    private var footer: some View {
        HStack {
            statusLabel
            Spacer()
            if case .failed = model.phase {
                Button("Try Again") { Task { await runInstall() } }
                    .buttonStyle(.bordered)
            }
            Button {
                Task { await runInstall() }
            } label: {
                HStack(spacing: 6) {
                    if model.isRunning {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.down.circle.fill")
                    }
                    Text(model.isRunning ? "Installing…" : "Install")
                }
                .frame(minWidth: 110)
            }
            .keyboardShortcut(.defaultAction)
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .disabled(model.isRunning)
        }
        .padding(20)
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch model.phase {
        case .idle:
            Label("Ready to install", systemImage: "circle.dashed")
                .foregroundStyle(.secondary)
        case .installingBootstrap:
            Label("Installing \(model.choice.displayName)…", systemImage: "arrow.triangle.2.circlepath")
                .foregroundStyle(.secondary)
        case .installingTool:
            Label("Installing remove-ai-watermarks…", systemImage: "arrow.triangle.2.circlepath")
                .foregroundStyle(.secondary)
        case .verifying:
            Label("Verifying…", systemImage: "checkmark.seal")
                .foregroundStyle(.secondary)
        case .done:
            Label("Installed", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed(let msg):
            Label(msg, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .lineLimit(2)
        }
    }

    // MARK: - Install flow

    private func runInstall() async {
        model.reset()

        do {
            let bootstrapURL = try await ensureBootstrap()
            model.phase = .installingTool
            model.log("$ \(bootstrapURL.lastPathComponent) \(toolInstallArgs.joined(separator: " "))")
            try await streamRun(executable: bootstrapURL, args: toolInstallArgs)

            model.phase = .verifying
            await app.reprobe()
            if app.cliPath != nil {
                model.phase = .done
                model.log("✓ remove-ai-watermarks is available at \(app.cliPath?.path ?? "")")
            } else {
                model.phase = .failed("Install finished but the tool wasn't found on PATH. Try restarting the app.")
            }
        } catch let error as CLIError {
            model.phase = .failed(error.errorDescription ?? "Install failed")
        } catch {
            model.phase = .failed(error.localizedDescription)
        }
    }

    private var toolInstallArgs: [String] {
        switch model.choice {
        case .uv:
            return ["tool", "install", "git+https://github.com/wiltodelta/remove-ai-watermarks.git"]
        case .pipx:
            return ["install", "git+https://github.com/wiltodelta/remove-ai-watermarks.git"]
        }
    }

    /// Returns the bootstrap binary (`uv` or `pipx`). Installs `uv` via the official
    /// shell installer if missing. For pipx, surfaces a clear error rather than auto-installing.
    private func ensureBootstrap() async throws -> URL {
        if let found = CLIProbe.findExecutable(named: model.choice.binaryName) {
            model.log("Found \(model.choice.displayName) at \(found.path)")
            return found
        }

        switch model.choice {
        case .uv:
            model.phase = .installingBootstrap
            model.log("uv not found — running official installer…")
            let sh = URL(fileURLWithPath: "/bin/sh")
            try await streamRun(
                executable: sh,
                args: ["-c", "curl -LsSf https://astral.sh/uv/install.sh | sh"]
            )
            if let found = CLIProbe.findExecutable(named: "uv") {
                model.log("✓ uv installed at \(found.path)")
                return found
            }
            throw CLIError.launchFailed("uv installed but couldn't be located on disk.")
        case .pipx:
            throw CLIError.launchFailed("pipx isn't installed. Install it first (e.g. brew install pipx) or switch to uv.")
        }
    }

    private func streamRun(executable: URL, args: [String]) async throws {
        for try await line in CLIRunner.stream(executable: executable, arguments: args) {
            model.log(line)
        }
    }
}
