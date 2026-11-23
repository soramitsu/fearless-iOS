import SwiftUI

/// Path builders shared by the seal, the dial and the loader. Figures use
/// outer radius 1 about the origin with y down; `scale` and `centre` place
/// them in a view.
enum ShikibanGeometry {
    /// Maps a unit-figure point into view space.
    static func point(_ x: CGFloat, _ y: CGFloat, centre: CGPoint, scale: CGFloat) -> CGPoint {
        CGPoint(x: centre.x + x * scale, y: centre.y + y * scale)
    }

    /// A stroke of the solar geometry as a path. Circles start at 12 o'clock
    /// and run anticlockwise, as the kit draws them.
    static func path(for stroke: SolarStroke, centre: CGPoint, scale: CGFloat) -> Path {
        switch stroke.shape {
        case let .line(x1, y1, x2, y2):
            var path = Path()
            path.move(to: point(x1, y1, centre: centre, scale: scale))
            path.addLine(to: point(x2, y2, centre: centre, scale: scale))
            return path
        case let .circle(cx, cy, r):
            return circle(cx: cx, cy: cy, r: r, centre: centre, scale: scale, clockwise: false)
        }
    }

    /// A full circle from 12 o'clock as a polyline, so it can be trimmed in a known direction.
    static func circle(cx: CGFloat, cy: CGFloat, r: CGFloat, centre: CGPoint, scale: CGFloat, clockwise: Bool, segments: Int = 96) -> Path {
        var path = Path()
        for step in 0...segments {
            let turn = CGFloat(step) / CGFloat(segments)
            let angle = -CGFloat.pi / 2 + (clockwise ? 1 : -1) * 2 * .pi * turn
            let p = point(cx + r * cos(angle), cy + r * sin(angle), centre: centre, scale: scale)
            if step == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        return path
    }

    /// An arc of a circle about the figure's centre, clockwise from 12
    /// o'clock, between two turn fractions.
    static func arc(radius: CGFloat, fromTurn: Double, toTurn: Double, centre: CGPoint, scale: CGFloat) -> Path {
        var path = Path()
        let span = max(0, toTurn - fromTurn)
        let segments = max(2, Int((span * 64).rounded(.up)))
        for step in 0...segments {
            let turn = fromTurn + span * Double(step) / Double(segments)
            let angle = -Double.pi / 2 + 2 * Double.pi * turn
            let p = point(radius * CGFloat(cos(angle)), radius * CGFloat(sin(angle)), centre: centre, scale: scale)
            if step == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        return path
    }

    /// The mirror's eight-lobed rim as one closed polyline, clockwise from its top-left cusp.
    static func mirrorRim(centre: CGPoint, scale: CGFloat, segmentsPerLobe: Int = 14) -> Path {
        var path = Path()
        var started = false
        for lobe in ShikibanTokens.mirrorRim {
            for step in 0...segmentsPerLobe {
                let angle = lobe.from + (lobe.to - lobe.from) * CGFloat(step) / CGFloat(segmentsPerLobe)
                let p = point(lobe.cx + lobe.r * cos(angle), lobe.cy + lobe.r * sin(angle), centre: centre, scale: scale)
                if started { path.addLine(to: p) } else { path.move(to: p); started = true }
            }
        }
        path.closeSubpath()
        return path
    }

    /// A stretch of a closed path between two fractions, wrapping past the end.
    static func wrappedTrim(_ path: Path, from start: Double, length: Double) -> [Path] {
        let from = start - floor(start)
        let to = from + length
        if to <= 1 {
            return [path.trimmedPath(from: from, to: to)]
        }
        return [path.trimmedPath(from: from, to: 1), path.trimmedPath(from: 0, to: to - 1)]
    }

    /// The kit's `easing.settle` as a function of progress.
    static func settle(_ t: Double) -> Double {
        let x = min(1, max(0, t))
        // A close closed form of cubic-bezier(0.05, 0.7, 0.1, 1): fast start, long settle.
        return 1 - pow(1 - x, 3.2)
    }
}
