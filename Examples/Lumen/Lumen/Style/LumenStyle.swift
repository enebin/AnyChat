import SwiftUI
import UIKit
import AnyChatUI

enum LumenStyle {
    static let ink = Color(light: 0x0D0D0D, dark: 0xF2F2F2)
    static let secondaryInk = Color(light: 0x6E6E6E, dark: 0xA3A3A3)
    static let background = Color(light: 0xFFFFFF, dark: 0x121212)
    static let userBubble = Color(light: 0xF3F3F3, dark: 0x2A2A2A)
    static let card = Color(light: 0xF7F7F7, dark: 0x1E1E1E)
    static let divider = Color(light: 0xE8E8E8, dark: 0x2E2E2E)
    static let codeBackground = Color(light: 0xF7F7F7, dark: 0x1E1E1E)
    static let sheetBackground = Color(light: 0xF1F1F1, dark: 0x1C1C1C)
    static let tile = Color(light: 0xE2E2E2, dark: 0x2C2C2C)
    /// The round send / voice / stop button, which inverts with the color scheme.
    static let actionFill = Color(light: 0x0D0D0D, dark: 0xF2F2F2)
    static let actionGlyph = Color(light: 0xFFFFFF, dark: 0x0D0D0D)

    static let bodyFont = Font.system(size: 17)
    static let bodyLineSpacing: CGFloat = 25 - UIFont.systemFont(ofSize: 17).lineHeight

    static var channelTheme: ChannelTheme {
        var theme = ChannelTheme.adaptive
        theme.background = background
        theme.outgoingBubbleBackground = userBubble
        theme.outgoingMessageText = ink
        theme.incomingMessageText = ink
        theme.accent = ink
        theme.messageFont = bodyFont
        theme.composerBackground = .clear
        theme.composerButtonTint = ink
        theme.sendingIndicatorTint = secondaryInk
        return theme
    }

    static var channelListTheme: ChannelListTheme {
        var theme = ChannelListTheme.adaptive
        theme.background = background
        theme.separator = .clear
        theme.placeholderTint = secondaryInk
        return theme
    }
}

extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}

/// The brand mark: a four-point spark around a small ring.
struct LumenMark: Shape {
    func path(in rect: CGRect) -> Path {
        let size = min(rect.width, rect.height)
        let scale = size / 24
        let origin = CGPoint(x: rect.midX - size / 2, y: rect.midY - size / 2)
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: origin.x + x * scale, y: origin.y + y * scale)
        }
        var path = Path()
        path.move(to: point(12, 2.5))
        path.addCurve(to: point(21.5, 12), control1: point(12.8, 8.2), control2: point(15.8, 11.2))
        path.addCurve(to: point(12, 21.5), control1: point(15.8, 12.8), control2: point(12.8, 15.8))
        path.addCurve(to: point(2.5, 12), control1: point(11.2, 15.8), control2: point(8.2, 12.8))
        path.addCurve(to: point(12, 2.5), control1: point(8.2, 11.2), control2: point(11.2, 8.2))
        path.closeSubpath()
        path.addEllipse(in: CGRect(origin: point(9.8, 9.8), size: CGSize(width: 4.4 * scale, height: 4.4 * scale)))
        return path
    }
}
