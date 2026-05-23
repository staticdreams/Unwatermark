import Foundation

@Observable
final class ImageJob: Identifiable {
    enum Status: Equatable {
        case pending
        case processing
        case done
        case failed(String)
    }

    let id = UUID()
    let source: URL
    var output: URL?
    var status: Status = .pending
    var startedAt: Date?
    var finishedAt: Date?

    init(source: URL) {
        self.source = source
    }

    var displayName: String { source.lastPathComponent }
}
