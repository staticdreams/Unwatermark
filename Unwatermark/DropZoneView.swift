import SwiftUI
import UniformTypeIdentifiers

struct DropZoneView: View {
    @Environment(AppState.self) private var app
    @State private var isTargeted = false
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            // Animated rotating gradient ring.
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .strokeBorder(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.45, green: 0.40, blue: 0.95),
                            Color(red: 0.95, green: 0.40, blue: 0.75),
                            Color(red: 0.45, green: 0.85, blue: 0.95),
                            Color(red: 0.45, green: 0.40, blue: 0.95)
                        ]),
                        center: .center,
                        angle: .degrees(rotation)
                    ),
                    lineWidth: isTargeted ? 3 : 1.5
                )
                .background(
                    RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                        .fill(isTargeted ? Theme.dimGradient : LinearGradient(colors: [Color.secondary.opacity(0.05)], startPoint: .top, endPoint: .bottom))
                )

            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Theme.dimGradient)
                        .frame(width: 76, height: 76)
                        .scaleEffect(isTargeted ? 1.15 : 1.0)
                    Image(systemName: "square.and.arrow.down.on.square")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(Theme.accentGradient)
                        .symbolEffect(.bounce, value: isTargeted)
                }
                Text("Drop AI-generated images here")
                    .font(.title3.weight(.medium))
                Text("PNG, JPEG, WebP — single file or batch.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .scaleEffect(isTargeted ? 1.02 : 1.0)
        .animation(Theme.smoothEase, value: isTargeted)
        .onAppear {
            withAnimation(.linear(duration: 14).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        let group = DispatchGroup()
        var urls: [URL] = []

        for provider in providers {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                defer { group.leave() }
                guard let url else { return }
                if Self.isAcceptableImage(url) {
                    urls.append(url)
                }
            }
        }

        group.notify(queue: .main) {
            guard !urls.isEmpty else { return }
            Task { @MainActor in
                app.enqueue(urls)
            }
        }
        return true
    }

    private static let imageExtensions: Set<String> = [
        "png", "jpg", "jpeg", "webp", "tif", "tiff", "heic", "bmp"
    ]

    private static func isAcceptableImage(_ url: URL) -> Bool {
        imageExtensions.contains(url.pathExtension.lowercased())
    }
}
