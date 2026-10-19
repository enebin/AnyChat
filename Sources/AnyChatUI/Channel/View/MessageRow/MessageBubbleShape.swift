import SwiftUI

struct MessageBubbleShape: Shape {
    static let cornerRadius: CGFloat = 20
    /// The source tail extends 6.946pt below the body; reserve a full point boundary.
    static let tailHeight: CGFloat = 7

    let isMine: Bool
    let showsTail: Bool

    func path(in rect: CGRect) -> Path {
        let bodyRect = CGRect(
            origin: rect.origin,
            size: CGSize(width: rect.width, height: max(0, rect.height - (showsTail ? Self.tailHeight : 0)))
        )
        let body = Path(roundedRect: bodyRect, cornerRadius: Self.cornerRadius)
        guard showsTail else { return body }
        var tail = Path()
        tail.move(to: CGPoint(x: rect.maxX - 32 + -0.00000000, y: bodyRect.maxY - 4.80052185 + 4.80052185))
        tail.addCurve(to: CGPoint(x: rect.maxX - 32 + 9.78523966, y: bodyRect.maxY - 4.80052185 + 4.80052185), control1: CGPoint(x: rect.maxX - 32 + 1.13089627, y: bodyRect.maxY - 4.80052185 + 4.80052185), control2: CGPoint(x: rect.maxX - 32 + 6.72025242, y: bodyRect.maxY - 4.80052185 + 4.80052185))
        tail.addCurve(to: CGPoint(x: rect.maxX - 32 + 12.75304401, y: bodyRect.maxY - 4.80052185 + 6.04052185), control1: CGPoint(x: rect.maxX - 32 + 10.77205409, y: bodyRect.maxY - 4.80052185 + 4.80052185), control2: CGPoint(x: rect.maxX - 32 + 11.42038369, y: bodyRect.maxY - 4.80052185 + 5.10808637))
        tail.addCurve(to: CGPoint(x: rect.maxX - 32 + 18.47431610, y: bodyRect.maxY - 4.80052185 + 9.89052185), control1: CGPoint(x: rect.maxX - 32 + 13.46213838, y: bodyRect.maxY - 4.80052185 + 6.53666084), control2: CGPoint(x: rect.maxX - 32 + 16.20482230, y: bodyRect.maxY - 4.80052185 + 8.63924306))
        tail.addCurve(to: CGPoint(x: rect.maxX - 32 + 22.53764963, y: bodyRect.maxY - 4.80052185 + 11.74052185), control1: CGPoint(x: rect.maxX - 32 + 20.43288034, y: bodyRect.maxY - 4.80052185 + 10.97037053), control2: CGPoint(x: rect.maxX - 32 + 22.11666297, y: bodyRect.maxY - 4.80052185 + 11.70765062))
        tail.addCurve(to: CGPoint(x: rect.maxX - 32 + 23.46273017, y: bodyRect.maxY - 4.80052185 + 10.01052185), control1: CGPoint(x: rect.maxX - 32 + 23.79425603, y: bodyRect.maxY - 4.80052185 + 11.83863943), control2: CGPoint(x: rect.maxX - 32 + 23.95267336, y: bodyRect.maxY - 4.80052185 + 10.65253792))
        tail.addCurve(to: CGPoint(x: rect.maxX - 32 + 22.19665957, y: bodyRect.maxY - 4.80052185 + 8.09052185), control1: CGPoint(x: rect.maxX - 32 + 22.97278698, y: bodyRect.maxY - 4.80052185 + 9.36850578), control2: CGPoint(x: rect.maxX - 32 + 22.41258216, y: bodyRect.maxY - 4.80052185 + 8.54081975))
        tail.addCurve(to: CGPoint(x: rect.maxX - 32 + 21.56936156, y: bodyRect.maxY - 4.80052185 + 5.04052185), control1: CGPoint(x: rect.maxX - 32 + 21.71339700, y: bodyRect.maxY - 4.80052185 + 7.08269717), control2: CGPoint(x: rect.maxX - 32 + 21.56936156, y: bodyRect.maxY - 4.80052185 + 6.55360410))
        tail.addCurve(to: CGPoint(x: rect.maxX - 32 + 23.92972419, y: bodyRect.maxY - 4.80052185 + 0.87934875), control1: CGPoint(x: rect.maxX - 32 + 21.56936156, y: bodyRect.maxY - 4.80052185 + 3.18060781), control2: CGPoint(x: rect.maxX - 32 + 22.89036172, y: bodyRect.maxY - 4.80052185 + 1.79867034))
        tail.addCurve(to: CGPoint(x: rect.maxX - 32 + 25.00000000, y: bodyRect.maxY - 4.80052185 + 0.00000000), control1: CGPoint(x: rect.maxX - 32 + 24.19033131, y: bodyRect.maxY - 4.80052185 + 0.64884038), control2: CGPoint(x: rect.maxX - 32 + 24.66056598, y: bodyRect.maxY - 4.80052185 + 0.28899077))
        tail.addCurve(to: CGPoint(x: rect.maxX - 32 + -0.00000000, y: bodyRect.maxY - 4.80052185 + 4.80052185), control1: CGPoint(x: rect.maxX - 32 + 25.00000000, y: bodyRect.maxY - 4.80052185 + 0.00000000), control2: CGPoint(x: rect.maxX - 32 + -0.00000000, y: bodyRect.maxY - 4.80052185 + 4.80052185))
        tail.closeSubpath()
        if !isMine {
            tail = tail.applying(CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: rect.minX + rect.maxX, ty: 0))
        }
        return body.union(tail)
    }
}
