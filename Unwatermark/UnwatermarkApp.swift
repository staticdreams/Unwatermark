import SwiftUI

@main
struct UnwatermarkApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .task {
                    appDelegate.attach { urls in
                        appState.handleExternalOpen(urls: urls)
                    }
                }
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 760, height: 580)
    }
}
