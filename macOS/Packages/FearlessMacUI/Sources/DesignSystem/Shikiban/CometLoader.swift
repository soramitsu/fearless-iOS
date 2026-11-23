import SwiftUI

/// The brand loader: three comets (the crow's three legs) circling the
/// mirror's eight-lobed rim. With Reduce Motion the comets stand still and
/// brighten in turn.
public struct CometLoader: View {
    private let size: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.staticRendering) private var staticRendering

    public init(size: CGFloat = 24) {
        self.size = size
    }

    public var body: some View {
        Group {
            if staticRendering {
                Canvas { context, canvasSize in
                    draw(in: &context, size: canvasSize, turn: 0.1, emphasis: nil)
                }
            } else if reduceMotion {
                TimelineView(.periodic(from: .now, by: BrandMotion.d720)) { timeline in
                    Canvas { context, canvasSize in
                        let step = Int(timeline.date.timeIntervalSinceReferenceDate / BrandMotion.d720) % ShikibanTokens.loaderComets
                        draw(in: &context, size: canvasSize, turn: 0.1, emphasis: step)
                    }
                }
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                    Canvas { context, canvasSize in
                        let turn = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: ShikibanTokens.loaderSecondsPerTurn) / ShikibanTokens.loaderSecondsPerTurn
                        draw(in: &context, size: canvasSize, turn: turn, emphasis: nil)
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel("Loading")
    }

    private func draw(in context: inout GraphicsContext, size: CGSize, turn: Double, emphasis: Int?) {
        let centre = CGPoint(x: size.width / 2, y: size.height / 2)
        let scale = min(size.width, size.height) / 2 * 0.92
        let rim = ShikibanGeometry.mirrorRim(centre: centre, scale: scale)
        let width = max(1.2, scale * 0.085)
        let rest = Color.primary.opacity(ShikibanTokens.loaderRestAlpha)
        context.stroke(rim, with: .color(rest), style: StrokeStyle(lineWidth: width * 0.7, lineJoin: .round))
        let inner = ShikibanTokens.mirrorCusp * 0.94 / 2.squareRoot()
        let innerPath = ShikibanGeometry.circle(cx: 0, cy: 0, r: inner, centre: centre, scale: scale, clockwise: true, segments: 48)
        context.stroke(innerPath, with: .color(rest), lineWidth: width * 0.6)

        let pieces = 7
        for comet in 0..<ShikibanTokens.loaderComets {
            let head = turn + Double(comet) / Double(ShikibanTokens.loaderComets)
            let strength = emphasis.map { $0 == comet ? 1.0 : 0.35 } ?? 1.0
            for piece in 0..<pieces {
                let start = head - ShikibanTokens.loaderTailTurn * Double(pieces - piece) / Double(pieces)
                let length = ShikibanTokens.loaderTailTurn / Double(pieces)
                let alpha = Double(piece + 1) / Double(pieces) * strength
                for segment in ShikibanGeometry.wrappedTrim(rim, from: start, length: length) {
                    context.stroke(segment, with: .color(BrandColor.inFlight.opacity(alpha)), style: StrokeStyle(lineWidth: width, lineCap: .round))
                }
            }
        }
    }
}
