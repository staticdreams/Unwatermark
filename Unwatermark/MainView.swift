import SwiftUI

struct MainView: View {
    @Environment(AppState.self) private var app
    @State private var showAllModeSheet = false

    var body: some View {
        @Bindable var app = app

        VStack(spacing: 16) {
            header
            DropZoneView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if !app.jobs.isEmpty {
                ProcessingListView()
            }
        }
        .padding(20)
        .background(.background)
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
