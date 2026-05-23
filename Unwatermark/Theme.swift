import SwiftUI

enum Theme {
    static let accentGradient = LinearGradient(
        colors: [
            Color(red: 0.45, green: 0.40, blue: 0.95),
            Color(red: 0.95, green: 0.40, blue: 0.75)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let dimGradient = LinearGradient(
        colors: [
            Color(red: 0.45, green: 0.40, blue: 0.95).opacity(0.35),
            Color(red: 0.95, green: 0.40, blue: 0.75).opacity(0.35)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cornerRadius: CGFloat = 18
    static let cardRadius: CGFloat = 12
    static let smoothEase: Animation = .smooth(duration: 0.35)
    static let springy: Animation = .spring(response: 0.45, dampingFraction: 0.7)
}
