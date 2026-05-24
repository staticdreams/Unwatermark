import AppKit

/// Receives URLs for files dropped on the Dock icon or opened via Finder's
/// "Open With…". Buffers them until `AppState` attaches a handler, then forwards
/// every subsequent batch immediately.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var onOpenURLs: (([URL]) -> Void)?
    private var buffered: [URL] = []

    func attach(_ handler: @escaping ([URL]) -> Void) {
        onOpenURLs = handler
        if !buffered.isEmpty {
            let urls = buffered
            buffered.removeAll()
            handler(urls)
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        if let onOpenURLs {
            onOpenURLs(urls)
        } else {
            buffered.append(contentsOf: urls)
        }
    }
}
