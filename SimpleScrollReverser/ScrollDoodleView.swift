import SwiftUI

/// Subtle looping doodle of a mouse and trackpad with independent scroll direction.
/// Honors Reduce Motion and uses only semantic colors so it tracks light/dark mode.
struct ScrollDoodleView: View {
    var reverseMouse: Bool
    var reverseTrackpad: Bool
    var enabled: Bool
    var lastDevice: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: reduceMotion)) { timeline in
            doodle(time: reduceMotion ? 0.35 : timeline.date.timeIntervalSinceReferenceDate)
        }
        .frame(width: 148, height: 88)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Illustration of mouse and trackpad scrolling independently.")
    }

    private func doodle(time: TimeInterval) -> some View {
        Canvas { context, size in
            let ink = Color.secondary
            let muted = Color.secondary.opacity(0.45)
            let cycle = 2.6
            let phase = CGFloat((time / cycle).truncatingRemainder(dividingBy: 1.0))
            let wave = sin(phase * 2 * .pi)
            let amplitude: CGFloat = enabled ? 7 : 2.5

            let mouseRect = CGRect(x: 14, y: 16, width: 28, height: 54)
            let padRect = CGRect(x: 86, y: 22, width: 48, height: 40)

            let mouseFocus = lastDevice == "Mouse"
            let padFocus = lastDevice == "Trackpad"
            let mouseInk = (mouseFocus || lastDevice == nil) ? ink : muted
            let padInk = (padFocus || lastDevice == nil) ? ink : muted

            drawMouse(context: context, rect: mouseRect, color: mouseInk)
            drawTrackpad(context: context, rect: padRect, color: padInk)

            let mouseTravel = wave * amplitude * (reverseMouse ? -1 : 1)
            let padTravel = wave * amplitude * (reverseTrackpad ? -1 : 1)
            drawScrollStream(
                context: context,
                in: mouseRect.insetBy(dx: 6, dy: 14),
                offset: mouseTravel,
                reverse: reverseMouse,
                color: mouseInk
            )
            drawScrollStream(
                context: context,
                in: padRect.insetBy(dx: 10, dy: 8),
                offset: padTravel,
                reverse: reverseTrackpad,
                color: padInk
            )

            var caption = context.resolve(Text("mouse").font(.system(size: 9, weight: .medium)).foregroundColor(mouseInk))
            context.draw(caption, at: CGPoint(x: mouseRect.midX, y: size.height - 8), anchor: .center)
            caption = context.resolve(Text("trackpad").font(.system(size: 9, weight: .medium)).foregroundColor(padInk))
            context.draw(caption, at: CGPoint(x: padRect.midX, y: size.height - 8), anchor: .center)
        }
        .opacity(colorScheme == .dark ? 0.95 : 1)
    }

    private func drawMouse(context: GraphicsContext, rect: CGRect, color: Color) {
        let path = Path(roundedRect: rect, cornerRadius: rect.width / 2)
        context.stroke(path, with: .color(color), lineWidth: 1.5)
        var seam = Path()
        seam.move(to: CGPoint(x: rect.midX, y: rect.minY + 3))
        seam.addLine(to: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.36))
        context.stroke(seam, with: .color(color.opacity(0.7)), style: StrokeStyle(lineWidth: 1, lineCap: .round))
    }

    private func drawTrackpad(context: GraphicsContext, rect: CGRect, color: Color) {
        let path = Path(roundedRect: rect, cornerRadius: 8)
        context.stroke(path, with: .color(color), lineWidth: 1.5)
        let fingerY = rect.minY + 11
        let left = CGRect(x: rect.midX - 11, y: fingerY, width: 7, height: 7)
        let right = CGRect(x: rect.midX + 4, y: fingerY, width: 7, height: 7)
        context.stroke(Path(ellipseIn: left), with: .color(color.opacity(0.8)), lineWidth: 1)
        context.stroke(Path(ellipseIn: right), with: .color(color.opacity(0.8)), lineWidth: 1)
    }

    private func drawScrollStream(
        context: GraphicsContext,
        in rect: CGRect,
        offset: CGFloat,
        reverse: Bool,
        color: Color
    ) {
        let count = 3
        for index in 0..<count {
            let fraction = CGFloat(index) / CGFloat(count - 1)
            let y = rect.minY + 6 + fraction * (rect.height - 12) + offset * 0.35
            let fade = 0.25 + 0.75 * (1 - abs(fraction - 0.5) * 2)
            var chevron = Path()
            let width: CGFloat = 6
            let height: CGFloat = reverse ? -4 : 4
            chevron.move(to: CGPoint(x: rect.midX - width, y: y - height))
            chevron.addLine(to: CGPoint(x: rect.midX, y: y + height * 0.15))
            chevron.addLine(to: CGPoint(x: rect.midX + width, y: y - height))
            var ctx = context
            ctx.opacity = fade
            ctx.stroke(chevron, with: .color(color), style: StrokeStyle(lineWidth: 1.25, lineCap: .round, lineJoin: .round))
        }
    }
}
