import SwiftUI
import AppKit

/// Draggable before/after slider. Drag anywhere over the image to move the divider.
struct BeforeAfterView: View {
    let beforeURL: URL
    let afterURL: URL

    @State private var beforeImage: NSImage?
    @State private var afterImage: NSImage?
    @State private var position: CGFloat = 0.5

    var body: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .fill(Color.black.opacity(0.04))

                if let before = beforeImage, let after = afterImage {
                    let size = geo.size

                    // AFTER — full image.
                    imageLayer(after, size: size)

                    // BEFORE — clipped from the left edge to the divider.
                    imageLayer(before, size: size)
                        .mask(alignment: .leading) {
                            Rectangle()
                                .frame(width: size.width * position)
                        }

                    divider(in: size)
                    cornerLabels(in: size)
                } else {
                    ProgressView()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 1)
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let x = value.location.x / max(geo.size.width, 1)
                        position = min(max(x, 0), 1)
                    }
            )
        }
        .task(id: beforeURL) { beforeImage = await Self.load(beforeURL) }
        .task(id: afterURL) { afterImage = await Self.load(afterURL) }
    }

    private func imageLayer(_ image: NSImage, size: CGSize) -> some View {
        Image(nsImage: image)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(width: size.width, height: size.height)
    }

    private func divider(in size: CGSize) -> some View {
        let x = size.width * position
        return ZStack {
            Rectangle()
                .fill(Color.white)
                .frame(width: 2)
                .shadow(color: .black.opacity(0.35), radius: 2)

            Circle()
                .fill(.white)
                .frame(width: 30, height: 30)
                .overlay(
                    Image(systemName: "arrow.left.and.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.black.opacity(0.7))
                )
                .shadow(color: .black.opacity(0.3), radius: 4, y: 1)
        }
        .frame(height: size.height)
        .position(x: x, y: size.height / 2)
        .allowsHitTesting(false)
    }

    private func cornerLabels(in size: CGSize) -> some View {
        ZStack {
            label("BEFORE")
                .position(x: 46, y: 18)
                .opacity(position > 0.08 ? 1 : 0)
            label("AFTER")
                .position(x: size.width - 38, y: 18)
                .opacity(position < 0.92 ? 1 : 0)
        }
        .animation(.easeOut(duration: 0.15), value: position)
        .allowsHitTesting(false)
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .tracking(0.5)
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(.black.opacity(0.55)))
    }

    private static func load(_ url: URL) async -> NSImage? {
        await Task.detached(priority: .userInitiated) {
            NSImage(contentsOf: url)
        }.value
    }
}
