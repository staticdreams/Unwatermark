import SwiftUI

@main
struct UnwatermarkApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 760, height: 580)
    }
}
