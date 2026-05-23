import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        Group {
            switch app.phase {
            case .probing:
                ProbingView()
            case .needsSetup:
                SetupView()
            case .ready:
                MainView()
            }
        }
        .frame(minWidth: 720, minHeight: 560)
        .task {
            if app.phase == .probing {
                await app.probe()
            }
        }
        .animation(Theme.smoothEase, value: app.phase)
    }
}

private struct ProbingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Looking for remove-ai-watermarks…")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }
}
