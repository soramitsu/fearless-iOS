import SwiftUI

/// The sync dial: a ring of eight segments that reports how many networks
/// have answered since the sync began. Lit segments are finished shares, the
/// last share is ember for networks that gave up, and a comet circles while
/// anything is outstanding. When everything has answered or given up the
/// comet stops and a dot fills the centre. It never estimates.
public struct SyncDial: View {
    private let done: Int
    private let failed: Int
    private let total: Int
    private let size: CGFloat

    @MotionAllowed private var motionAllowed

    /// - Parameters:
    ///   - done: networks that answered since this sync began.
    ///   - failed: networks that gave up.
    ///   - total: networks the wallet reads from.
    public init(done: Int, failed: Int, total: Int, size: CGFloat = 18) {
        self.done = max(0, done)
        self.failed = max(0, failed)
        self.total = max(0, total)
        self.size = size
    }

    private var outstanding: Bool { total > 0 && done + failed < total }

    public var body: some View {
        Group {
            if motionAllowed && outstanding {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    Canvas { context, canvasSize in
                        draw(in: &context, size: canvasSize, now: timeline.date)
                    }
                }
            } else {
                Canvas { context, canvasSize in
                    draw(in: &context, size: canvasSize, now: nil)
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel(outstanding ? "Syncing networks" : "Networks synced")
        .accessibilityValue(spokenValue)
    }

    private var spokenValue: String {
        if total == 0 { return "No networks" }
        if failed > 0 { return "\(done) of \(total) answered, \(failed) unavailable" }
        return "\(done) of \(total) answered"
    }

    private func draw(in context: inout GraphicsContext, size: CGSize, now: Date?) {
        let centre = CGPoint(x: size.width / 2, y: size.height / 2)
        let scale = min(size.width, size.height) / 2
        let radius: CGFloat = 0.78
        let width = max(1.5, scale * 0.22)
        let segments = ShikibanTokens.dialSegments
        let gap = ShikibanTokens.dialGapTurn * 2.4
        let doneShare = total > 0 ? Double(done) / Double(total) : 0
        let failedStart = total > 0 ? 1 - Double(failed) / Double(total) : 1
        let style = StrokeStyle(lineWidth: width, lineCap: .butt)

        for segment in 0..<segments {
            let start = Double(segment) / Double(segments) + gap / 2
            let end = Double(segment + 1) / Double(segments) - gap / 2
            let unlit = ShikibanGeometry.arc(radius: radius, fromTurn: start, toTurn: end, centre: centre, scale: scale)
            context.stroke(unlit, with: .color(Color.primary.opacity(0.18)), style: style)
            let litEnd = min(end, doneShare)
            if litEnd > start {
                let lit = ShikibanGeometry.arc(radius: radius, fromTurn: start, toTurn: litEnd, centre: centre, scale: scale)
                context.stroke(lit, with: .color(BrandColor.final), style: style)
            }
            let failStart = max(start, failedStart)
            if failed > 0, end > failStart {
                let lost = ShikibanGeometry.arc(radius: radius, fromTurn: failStart, toTurn: end, centre: centre, scale: scale)
                context.stroke(lost, with: .color(BrandColor.failure), style: style)
            }
        }

        if outstanding {
            if let now {
                let turn = now.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: ShikibanTokens.dialCometSeconds) / ShikibanTokens.dialCometSeconds
                let pieces = 6
                for piece in 0..<pieces {
                    let from = turn - ShikibanTokens.dialCometTurn * Double(pieces - piece) / Double(pieces)
                    let to = turn - ShikibanTokens.dialCometTurn * Double(pieces - piece - 1) / Double(pieces)
                    let arc = ShikibanGeometry.arc(radius: radius, fromTurn: from, toTurn: to, centre: centre, scale: scale)
                    context.stroke(arc, with: .color(BrandColor.inFlight.opacity(Double(piece + 1) / Double(pieces))), style: style)
                }
            }
        } else if total > 0 {
            let dot = scale * 0.3
            context.fill(
                Path(ellipseIn: CGRect(x: centre.x - dot, y: centre.y - dot, width: dot * 2, height: dot * 2)),
                with: .color(BrandColor.final)
            )
        }
    }
}
