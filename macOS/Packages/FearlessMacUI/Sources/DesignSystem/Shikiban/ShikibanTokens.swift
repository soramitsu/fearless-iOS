import CoreGraphics

// Generated from the Yatagarasu kit's `tokens/solar-geometry.json` and
// `tokens/shikiban.json` (kit manifest SHA-256
// 19675ac743881b28bcae83a24f3ee15702c5a8af2b7a5d901c858848c4d74cd7).
// Values are copied verbatim; do not edit by hand.

/// One stroke of the solar geometry. Figures use outer radius 1, origin at
/// the centre, y down. Circles start at 12 o'clock and run anticlockwise.
struct SolarStroke: Sendable {
    enum Shape: Sendable {
        case circle(cx: CGFloat, cy: CGFloat, r: CGFloat)
        case line(x1: CGFloat, y1: CGFloat, x2: CGFloat, y2: CGFloat)
    }

    enum Group: Sendable {
        case ring, hexagram, lattice, ray
    }

    let shape: Shape
    let group: Group
    let weight: CGFloat
    /// Progress window (0...1 of the ignite) over which the stroke draws.
    let revealStart: CGFloat
    let revealEnd: CGFloat
}

struct SolarStar: Sendable {
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let reveal: CGFloat
}

enum SolarGeometry {
    static let coreWidth: CGFloat = 0.0055
    static let glowWidth: CGFloat = 0.034
    static let tickCount = 132
    static let tickRadius: CGFloat = 0.978
    static let tickSize: CGFloat = 0.006
    static let tickTurnsPerSecond: Double = -0.002864788975654116

    static let strokes: [SolarStroke] = [
        SolarStroke(shape: .circle(cx: 0, cy: 0, r: 1), group: .ring, weight: 1.25, revealStart: 0, revealEnd: 0.3),
        SolarStroke(shape: .circle(cx: 0, cy: 0, r: 0.955), group: .ring, weight: 0.8, revealStart: 0.05, revealEnd: 0.34),
        SolarStroke(shape: .line(x1: 0, y1: -1, x2: -0.86603, y2: 0.5), group: .hexagram, weight: 1, revealStart: 0.26, revealEnd: 0.34),
        SolarStroke(shape: .line(x1: -0.86603, y1: 0.5, x2: 0.86603, y2: 0.5), group: .hexagram, weight: 1, revealStart: 0.295, revealEnd: 0.375),
        SolarStroke(shape: .line(x1: 0.86603, y1: 0.5, x2: 0, y2: -1), group: .hexagram, weight: 1, revealStart: 0.33, revealEnd: 0.41),
        SolarStroke(shape: .line(x1: -0.86603, y1: -0.5, x2: 0, y2: 1), group: .hexagram, weight: 1, revealStart: 0.365, revealEnd: 0.445),
        SolarStroke(shape: .line(x1: 0, y1: 1, x2: 0.86603, y2: -0.5), group: .hexagram, weight: 1, revealStart: 0.4, revealEnd: 0.48),
        SolarStroke(shape: .line(x1: 0.86603, y1: -0.5, x2: -0.86603, y2: -0.5), group: .hexagram, weight: 1, revealStart: 0.435, revealEnd: 0.515),
        SolarStroke(shape: .line(x1: 0, y1: -0.61, x2: 0.235, y2: -0.46), group: .lattice, weight: 0.72, revealStart: 0.5, revealEnd: 0.56),
        SolarStroke(shape: .line(x1: 0, y1: -0.61, x2: -0.235, y2: -0.46), group: .lattice, weight: 0.72, revealStart: 0.512, revealEnd: 0.572),
        SolarStroke(shape: .line(x1: 0.235, y1: -0.46, x2: -0.235, y2: -0.46), group: .lattice, weight: 0.72, revealStart: 0.524, revealEnd: 0.584),
        SolarStroke(shape: .line(x1: 0, y1: -0.61, x2: 0, y2: -0.34), group: .lattice, weight: 0.72, revealStart: 0.536, revealEnd: 0.596),
        SolarStroke(shape: .line(x1: 0.235, y1: -0.46, x2: 0, y2: -0.34), group: .lattice, weight: 0.72, revealStart: 0.548, revealEnd: 0.608),
        SolarStroke(shape: .line(x1: -0.235, y1: -0.46, x2: 0, y2: -0.34), group: .lattice, weight: 0.72, revealStart: 0.56, revealEnd: 0.62),
        SolarStroke(shape: .line(x1: 0.235, y1: -0.46, x2: 0.235, y2: -0.225), group: .lattice, weight: 0.72, revealStart: 0.572, revealEnd: 0.632),
        SolarStroke(shape: .line(x1: -0.235, y1: -0.46, x2: -0.235, y2: -0.225), group: .lattice, weight: 0.72, revealStart: 0.584, revealEnd: 0.644),
        SolarStroke(shape: .line(x1: 0, y1: -0.34, x2: 0.235, y2: -0.225), group: .lattice, weight: 0.72, revealStart: 0.596, revealEnd: 0.656),
        SolarStroke(shape: .line(x1: 0, y1: -0.34, x2: -0.235, y2: -0.225), group: .lattice, weight: 0.72, revealStart: 0.608, revealEnd: 0.668),
        SolarStroke(shape: .line(x1: 0, y1: -0.34, x2: 0, y2: -0.115), group: .lattice, weight: 0.72, revealStart: 0.62, revealEnd: 0.68),
        SolarStroke(shape: .line(x1: 0.235, y1: -0.225, x2: -0.235, y2: -0.225), group: .lattice, weight: 0.72, revealStart: 0.632, revealEnd: 0.692),
        SolarStroke(shape: .line(x1: 0.235, y1: -0.225, x2: 0, y2: -0.115), group: .lattice, weight: 0.72, revealStart: 0.644, revealEnd: 0.704),
        SolarStroke(shape: .line(x1: -0.235, y1: -0.225, x2: 0, y2: -0.115), group: .lattice, weight: 0.72, revealStart: 0.656, revealEnd: 0.716),
        SolarStroke(shape: .line(x1: 0.235, y1: -0.225, x2: 0.235, y2: 0.005), group: .lattice, weight: 0.72, revealStart: 0.668, revealEnd: 0.728),
        SolarStroke(shape: .line(x1: -0.235, y1: -0.225, x2: -0.235, y2: 0.005), group: .lattice, weight: 0.72, revealStart: 0.68, revealEnd: 0.74),
        SolarStroke(shape: .line(x1: 0, y1: -0.115, x2: 0.235, y2: 0.005), group: .lattice, weight: 0.72, revealStart: 0.692, revealEnd: 0.752),
        SolarStroke(shape: .line(x1: 0, y1: -0.115, x2: -0.235, y2: 0.005), group: .lattice, weight: 0.72, revealStart: 0.704, revealEnd: 0.764),
        SolarStroke(shape: .line(x1: 0, y1: -0.115, x2: 0, y2: 0.1), group: .lattice, weight: 0.72, revealStart: 0.716, revealEnd: 0.776),
        SolarStroke(shape: .line(x1: 0.235, y1: 0.005, x2: -0.235, y2: 0.005), group: .lattice, weight: 0.72, revealStart: 0.728, revealEnd: 0.788),
        SolarStroke(shape: .line(x1: 0.235, y1: 0.005, x2: 0, y2: 0.1), group: .lattice, weight: 0.72, revealStart: 0.74, revealEnd: 0.8),
        SolarStroke(shape: .line(x1: -0.235, y1: 0.005, x2: 0, y2: 0.1), group: .lattice, weight: 0.72, revealStart: 0.752, revealEnd: 0.812),
        SolarStroke(shape: .circle(cx: 0, cy: -0.61, r: 0.067), group: .lattice, weight: 0.72, revealStart: 0.74, revealEnd: 0.8),
        SolarStroke(shape: .circle(cx: 0.235, cy: -0.46, r: 0.067), group: .lattice, weight: 0.72, revealStart: 0.752, revealEnd: 0.812),
        SolarStroke(shape: .circle(cx: -0.235, cy: -0.46, r: 0.067), group: .lattice, weight: 0.72, revealStart: 0.764, revealEnd: 0.824),
        SolarStroke(shape: .circle(cx: 0, cy: -0.34, r: 0.067), group: .lattice, weight: 0.72, revealStart: 0.776, revealEnd: 0.836),
        SolarStroke(shape: .circle(cx: 0.235, cy: -0.225, r: 0.067), group: .lattice, weight: 0.72, revealStart: 0.788, revealEnd: 0.848),
        SolarStroke(shape: .circle(cx: -0.235, cy: -0.225, r: 0.067), group: .lattice, weight: 0.72, revealStart: 0.8, revealEnd: 0.86),
        SolarStroke(shape: .circle(cx: 0, cy: -0.115, r: 0.067), group: .lattice, weight: 0.72, revealStart: 0.812, revealEnd: 0.872),
        SolarStroke(shape: .circle(cx: 0.235, cy: 0.005, r: 0.067), group: .lattice, weight: 0.72, revealStart: 0.824, revealEnd: 0.884),
        SolarStroke(shape: .circle(cx: -0.235, cy: 0.005, r: 0.067), group: .lattice, weight: 0.72, revealStart: 0.836, revealEnd: 0.896),
        SolarStroke(shape: .circle(cx: 0, cy: 0.1, r: 0.067), group: .lattice, weight: 0.72, revealStart: 0.848, revealEnd: 0.908),
        SolarStroke(shape: .line(x1: 0, y1: -1, x2: 0, y2: 0.1), group: .ray, weight: 0.7, revealStart: 0.45, revealEnd: 0.6)
    ]

    static let stars: [SolarStar] = [
        SolarStar(x: 0, y: -1, size: 0.33, reveal: 0.3),
        SolarStar(x: -0.86603, y: -0.5, size: 0.25, reveal: 0.33),
        SolarStar(x: -0.86603, y: 0.5, size: 0.25, reveal: 0.36),
        SolarStar(x: 0, y: 1, size: 0.25, reveal: 0.39),
        SolarStar(x: 0.86603, y: 0.5, size: 0.25, reveal: 0.42),
        SolarStar(x: 0.86603, y: -0.5, size: 0.25, reveal: 0.45),
        SolarStar(x: 0, y: -0.61, size: 0.07, reveal: 0.76),
        SolarStar(x: 0.235, y: -0.46, size: 0.07, reveal: 0.772),
        SolarStar(x: -0.235, y: -0.46, size: 0.07, reveal: 0.784),
        SolarStar(x: 0, y: -0.34, size: 0.07, reveal: 0.796),
        SolarStar(x: 0.235, y: -0.225, size: 0.07, reveal: 0.808),
        SolarStar(x: -0.235, y: -0.225, size: 0.07, reveal: 0.82),
        SolarStar(x: 0, y: -0.115, size: 0.07, reveal: 0.832),
        SolarStar(x: 0.235, y: 0.005, size: 0.07, reveal: 0.844),
        SolarStar(x: -0.235, y: 0.005, size: 0.07, reveal: 0.856),
        SolarStar(x: 0, y: 0.1, size: 0.07, reveal: 0.868)
    ]

    /// Indices into `strokes` of the two rings and the six hexagram sides.
    static let ringIndices = [0, 1]
    static let hexagramIndices = [2, 3, 4, 5, 6, 7]
}

/// Numbers from `tokens/shikiban.json`.
enum ShikibanTokens {
    /// The only durations motion may use, in seconds.
    static let durations: [Double] = [0.09, 0.128, 0.18, 0.255, 0.36, 0.51, 0.72, 1.02]
    static let sealStageSeconds: Double = 0.36
    static let sealIgniteSeconds: Double = 0.72
    static let sealBreakSeconds: Double = 0.51
    static let sealCometSeconds: Double = 1.02
    static let sealRestStrength: Double = 0.25
    /// Index into `SolarGeometry.stars` of the star that lands with each stage.
    static let sealStarSigned = 2
    static let sealStarSent = 4
    static let sealStarAccepted = 0
    static let dialSegments = 8
    static let dialGapTurn: Double = 0.010416666666666666
    static let dialCometTurn: Double = 0.125
    static let dialCometSeconds: Double = 1.44
    static let dialSealSeconds: Double = 0.51
    static let loaderComets = 3
    static let loaderTailTurn: Double = 0.125
    static let loaderSecondsPerTurn: Double = 2.88
    static let loaderRestAlpha: Double = 0.25
    static let mirrorCusp: CGFloat = 0.92388

    /// The mirror's eight-lobed rim: arcs (centre, radius, start and end angle in radians, y down).
    static let mirrorRim: [(cx: CGFloat, cy: CGFloat, r: CGFloat, from: CGFloat, to: CGFloat)] = [
        (0, -0.5, 0.5, -2.35619, -0.7854),
        (0.35355, -0.35355, 0.5, -1.5708, 0),
        (0.5, 0, 0.5, -0.7854, 0.7854),
        (0.35355, 0.35355, 0.5, 0, 1.5708),
        (0, 0.5, 0.5, 0.7854, 2.35619),
        (-0.35355, 0.35355, 0.5, 1.5708, 3.14159),
        (-0.5, 0, 0.5, 2.35619, 3.92699),
        (-0.35355, -0.35355, 0.5, 3.14159, 4.71239)
    ]

    /// Asanoha tile (width 1, height √3): line segments x1, y1, x2, y2.
    static let asanohaHeight: CGFloat = 1.73205
    static let asanohaLines: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
        (0, 0, 1, 0),
        (1, 0, 0.5, 0.86603),
        (0.5, 0.86603, 0, 0),
        (0, 0, 0.5, 0.28868),
        (1, 0, 0.5, 0.28868),
        (0.5, 0.86603, 0.5, 0.28868),
        (0, 1.73205, 1, 1.73205),
        (1, 1.73205, 0.5, 0.86603),
        (0.5, 0.86603, 0, 1.73205),
        (0, 1.73205, 0.5, 1.44338),
        (1, 1.73205, 0.5, 1.44338),
        (0.5, 0.86603, 0.5, 1.44338),
        (0.5, 0.86603, 0, 0.86603),
        (0, 0.86603, 0, 0),
        (0, 0, 0.16667, 0.57735),
        (0.5, 0.86603, 0.16667, 0.57735),
        (0, 0.86603, 0.16667, 0.57735),
        (0, 0.86603, 0, 1.73205),
        (0, 1.73205, 0.16667, 1.1547),
        (0.5, 0.86603, 0.16667, 1.1547),
        (0, 0.86603, 0.16667, 1.1547),
        (0.5, 0.86603, 1, 0.86603),
        (1, 0.86603, 1, 0),
        (1, 0, 0.83333, 0.57735),
        (0.5, 0.86603, 0.83333, 0.57735),
        (1, 0.86603, 0.83333, 0.57735),
        (1, 0.86603, 1, 1.73205),
        (1, 1.73205, 0.83333, 1.1547),
        (0.5, 0.86603, 0.83333, 1.1547),
        (1, 0.86603, 0.83333, 1.1547)
    ]
}
