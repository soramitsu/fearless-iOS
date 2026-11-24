import UIKit

/// Brand kit v4, "Shikiban: depth, instruments and sacred geometry" (SPEC, 2026-11-15): every number of the launch
/// flight, the sync dial, the seal, the loader and the asanoha lattice, read from the kit's `tokens/shikiban.json`
/// (copied into the bundle by `scripts/brand/generate-ios-brand-assets.mjs`, never retyped).
///
/// Figures use outer radius 1, origin at the centre, y down; shikiban turns run clockwise from 12 o'clock. Depths and
/// the perspective are points; times are milliseconds.
struct FWShikiban: Decodable {
    struct Ratio: Decodable {
        let yamato: Double
        let ladder: [Double]
    }

    struct Easing: Decodable {
        let settle: [Double]
        let depart: [Double]
        let glide: [Double]
    }

    struct Colors: Decodable {
        let core: String
        let glow: String
        let star: String
        let flight: String
        let failure: String
        let rest: String
    }

    struct Depth: Decodable {
        let perspective: Double
    }

    struct Arc: Decodable {
        let cx: Double
        let cy: Double
        let r: Double
        let from: Double
        let to: Double
    }

    struct Mirror: Decodable {
        let lobes: Int
        let lobeRadius: Double
        let lobeCentre: Double
        let cusp: Double
        let rim: [Arc]
    }

    struct Gate: Decodable {
        let figure: String
        let diamond: Bool?
        let depth: Double
        let square: [[Double]]?

        var isMirror: Bool { figure == "mirror" }
    }

    /// A gradient stop written as `[offset, "#RRGGBB"]`.
    struct Stop: Decodable {
        let offset: Double
        let color: String

        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()
            offset = try container.decode(Double.self)
            color = try container.decode(String.self)
        }
    }

    struct Samples: Decodable {
        let camera: [Double]
        let iris: [Double]
        let gates: [[Double]]
        let gateAlpha: [[Double]]
        let tiers: [[Double]]
    }

    struct Flight: Decodable {
        let durationMs: Double
        let irisAtMs: Double
        let skipMs: Double
        let landingMs: Double
        let baseRadius: Double
        let passScale: Double
        let rest: Double
        let tierLag: Double
        let tierStaggerMs: Double
        let landingDepth: Double
        let landingLag: Double
        let gateFadeIn: Double
        let irisInset: Double
        let irisOpenMs: Double
        let coronaMs: Double
        let corona: [Stop]
        let tierFadeMs: Double
        let travel: Double
        let samples: Samples
        let landingFrom: [Double]
    }

    struct Dial: Decodable {
        let segments: Int
        let gapTurn: Double
        let cometTurn: Double
        let cometSeconds: Double
        let sealMs: Double
    }

    /// A stroke of `solar-geometry.json` named by its group and its index within the group: `["hexagram", 0]`.
    struct StrokeRef: Decodable, Equatable {
        let group: String
        let index: Int

        init(group: String, index: Int) {
            self.group = group
            self.index = index
        }

        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()
            group = try container.decode(String.self)
            index = try container.decode(Int.self)
        }
    }

    struct Seal: Decodable {
        let stages: [String]
        let progress: [String: Double]
        let stageMs: Double
        let igniteMs: Double
        let restMs: Double
        let restStrength: Double
        let breakMs: Double
        let cometSeconds: Double
        let strokes: [String: [StrokeRef]]
        let stars: [String: Int]
    }

    struct Loader: Decodable {
        let comets: Int
        let tailTurn: Double
        let secondsPerTurn: Double
        let restAlpha: Double
    }

    struct Asanoha: Decodable {
        let width: Double
        let height: Double
        let lines: [[Double]]
    }

    let formatVersion: Int
    let ratio: Ratio
    let durationsMs: [Double]
    let easing: Easing
    let colors: Colors
    let depth: Depth
    let mirror: Mirror
    let gates: [Gate]
    let flight: Flight
    let dial: Dial
    let seal: Seal
    let loader: Loader
    let asanoha: Asanoha

    static let bundled: FWShikiban? = load(from: .main)

    static func load(from bundle: Bundle) -> FWShikiban? {
        guard let url = bundle.url(forResource: "shikiban", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(FWShikiban.self, from: data)
    }

    /// A `#RRGGBB` colour of the file, as sRGB.
    static func color(_ hex: String, alpha: CGFloat = 1) -> UIColor {
        let digits = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        return FWSunlit.color(UInt32(digits, radix: 16) ?? 0xFFC24A, alpha: alpha)
    }

    var perspective: Double { depth.perspective }
}

// MARK: - The formulas (tools/shikiban.mjs)

extension FWShikiban {
    static func clamp01(_ value: Double) -> Double {
        min(1, max(0, value))
    }

    /// Rule 2: the scale of a plane at depth `z` (points, positive is away from the viewer).
    func depthScale(_ z: Double) -> Double {
        perspective / (perspective + z)
    }

    static func smootherstep(_ x: Double) -> Double {
        let k = clamp01(x)
        return k * k * k * (k * (6 * k - 15) + 10)
    }

    /// A cubic bezier easing as a function of time 0–1 (the curve Core Animation interpolates).
    static func bezier(_ points: [Double]) -> (Double) -> Double {
        guard points.count == 4 else { return { clamp01($0) } }
        let (x1, y1, x2, y2) = (points[0], points[1], points[2], points[3])
        let cx = 3 * x1, bx = 3 * (x2 - x1) - cx, ax = 1 - cx - bx
        let cy = 3 * y1, by = 3 * (y2 - y1) - cy, ay = 1 - cy - by
        func sampleX(_ t: Double) -> Double { ((ax * t + bx) * t + cx) * t }
        func sampleY(_ t: Double) -> Double { ((ay * t + by) * t + cy) * t }
        return { x in
            if x <= 0 { return 0 }
            if x >= 1 { return 1 }
            var lo = 0.0, hi = 1.0, t = x
            for _ in 0 ..< 24 {
                let value = sampleX(t)
                if abs(value - x) < 1e-6 { break }
                if value < x { lo = t } else { hi = t }
                t = (lo + hi) / 2
            }
            return sampleY(t)
        }
    }

    var settle: (Double) -> Double { Self.bezier(easing.settle) }

    static func timing(_ points: [Double]) -> CAMediaTimingFunction {
        guard points.count == 4 else { return CAMediaTimingFunction(name: .easeOut) }
        return CAMediaTimingFunction(
            controlPoints: Float(points[0]), Float(points[1]), Float(points[2]), Float(points[3])
        )
    }

    /// Camera position (points) at flight progress `u` (0–1).
    func cameraAt(_ u: Double) -> Double {
        flight.travel * Self.smootherstep(u)
    }

    /// Scale of gate `index` at flight progress `u`, or 0 once it has passed the viewer.
    func gateScale(_ index: Int, _ u: Double) -> Double {
        guard gates.indices.contains(index) else { return 0 }
        let distance = perspective + gates[index].depth - cameraAt(u)
        if distance <= perspective / flight.passScale { return 0 }
        return perspective / distance
    }

    /// How strongly gate `index` shows at flight progress `u`: far gates sit in haze, a gate fades as it sweeps past.
    func gateAlpha(_ index: Int, _ u: Double) -> Double {
        let scale = gateScale(index, u)
        guard scale > 0 else { return 0 }
        let haze = Self.clamp01((scale - 0.1) / 0.5)
        let pass = Self.clamp01((flight.passScale - scale) / (flight.passScale * 0.7))
        return (0.25 + 0.75 * haze) * pass
    }

    /// The mirror's opening: the last gate's scale without the pass cut-off.
    func irisScale(_ u: Double) -> Double {
        let distance = perspective + (gates.last?.depth ?? 0) - cameraAt(u)
        return perspective / max(distance, perspective / 400)
    }

    /// Scale of first-screen tier `tier` (0 nearest) at flight progress `u`; every tier ends at exactly 1.
    func tierScale(_ tier: Int, _ u: Double) -> Double {
        if u >= 1 { return 1 }
        let remaining = max(0, flight.travel - cameraAt(u))
        return depthScale(remaining * (1 + Double(tier) * flight.tierLag))
    }

    /// Scale of tier `tier` at landing progress `v` (0–1, already eased with `easing.settle`).
    func landingScale(_ tier: Int, _ v: Double) -> Double {
        depthScale(flight.landingDepth * (1 + Double(tier) * flight.landingLag) * (1 - Self.clamp01(v)))
    }

    /// The mirror opening's radius in points at flight time `ms` for a view whose shorter side is `side`.
    func irisRadius(atMs ms: Double, side: Double) -> Double {
        let open = Self.clamp01((ms - flight.irisAtMs) / flight.irisOpenMs)
        guard open > 0 else { return 0 }
        let u = Self.clamp01(ms / flight.durationMs)
        return flight.baseRadius * side * irisScale(u) * mirror.cusp * flight.irisInset * (1 - pow(1 - open, 3))
    }

    /// A tier's opacity at flight time `ms`: it fades in over `tierFadeMs` from `irisAtMs + tier × tierStaggerMs`.
    func tierOpacity(_ tier: Int, atMs ms: Double) -> Double {
        if ms >= flight.durationMs { return 1 }
        return Self.clamp01((ms - flight.irisAtMs - Double(tier) * flight.tierStaggerMs) / flight.tierFadeMs)
    }

    /// Core stroke width of a gate at `scale` (points).
    static func gateWidth(scale: Double) -> Double {
        min(4.5, 1 + 0.9 * scale)
    }

    /// How fast a skipped flight runs: the whole flight in `skipMs`.
    var skipRate: Double { flight.durationMs / flight.skipMs }
}

// MARK: - The sync dial

enum FWDialPhase: Equatable {
    /// Nothing known yet: the comet over an unlit ring.
    case idle
    case syncing
    /// Every network answered.
    case live
    /// Settled with some networks given up.
    case partial

    var isSettled: Bool { self == .live || self == .partial }
}

struct FWDialState: Equatable {
    let phase: FWDialPhase
    /// Gold share, as turns `[0, lit]`.
    let lit: ClosedRange<Double>
    /// Ember share at the end of the ring, `[1 - failed, 1]`.
    let failed: ClosedRange<Double>
    let done: Int
    let total: Int
}

extension FWShikiban {
    static func dialState(done: Int, failed: Int, total: Int) -> FWDialState {
        guard total > 0 else {
            return FWDialState(phase: .idle, lit: 0 ... 0, failed: 1 ... 1, done: 0, total: 0)
        }
        let answered = min(total, max(0, done))
        let gaveUp = min(total - answered, max(0, failed))
        let lit = Double(answered) / Double(total)
        let bad = Double(gaveUp) / Double(total)
        let settled = answered + gaveUp >= total
        let phase: FWDialPhase = settled ? (gaveUp > 0 ? .partial : .live) : .syncing
        return FWDialState(phase: phase, lit: 0 ... lit, failed: (1 - bad) ... 1, done: answered, total: total)
    }

    /// The part of segment `segment` covered by `arc`, in turns, or nil. Gaps between segments stay dark.
    func dialSegment(_ segment: Int, _ arc: ClosedRange<Double>) -> ClosedRange<Double>? {
        let count = Double(dial.segments)
        let a = Double(segment) / count + dial.gapTurn / 2
        let b = Double(segment + 1) / count - dial.gapTurn / 2
        let lo = max(a, arc.lowerBound), hi = min(b, arc.upperBound)
        return hi - lo > 1e-6 ? lo ... hi : nil
    }
}

// MARK: - The seal

/// A transfer's stages, in order. `idle` is before the final press.
enum FWSealStage: Int, Comparable, CaseIterable {
    case idle = 0
    case ready
    case signed
    case sent
    case accepted

    static func < (lhs: FWSealStage, rhs: FWSealStage) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var name: String {
        switch self {
        case .idle: return "idle"
        case .ready: return "ready"
        case .signed: return "signed"
        case .sent: return "sent"
        case .accepted: return "accepted"
        }
    }

    /// The seal's `q`: 1 ready (both rings), 2–4 the three sides of the upward triangle.
    var q: Double { Double(rawValue) }
}

extension FWShikiban {
    /// The solar geometry's ignite progress each stage draws to.
    func sealProgress(_ stage: FWSealStage) -> Double {
        seal.progress[stage.name] ?? 0
    }

    /// The strokes a stage draws.
    func sealStrokes(_ stage: FWSealStage) -> [StrokeRef] {
        seal.strokes[stage.name] ?? []
    }

    /// How much of `stroke` (index `index` in its group) the seal draws at stage position `q` (0–4) and ignite
    /// progress `p` (from `sealProgress(.accepted)` once accepted). Mirrors `drawSeal` in tools/shikiban-draw.mjs.
    func sealAmount(group: String, index: Int, reveal: ClosedRange<Double>, q: Double, p: Double) -> Double {
        for stage in [FWSealStage.ready, .signed, .sent, .accepted] {
            guard sealStrokes(stage).contains(StrokeRef(group: group, index: index)) else { continue }
            if stage == .ready { return Self.clamp01(q) }
            return Self.clamp01(q - Double(stage.rawValue - 1))
        }
        return q >= 4 ? Self.strokeProgress(reveal, p) : 0
    }

    static func strokeProgress(_ reveal: ClosedRange<Double>, _ p: Double) -> Double {
        if p <= reveal.lowerBound { return 0 }
        if p >= reveal.upperBound || reveal.upperBound <= reveal.lowerBound { return 1 }
        return (p - reveal.lowerBound) / (reveal.upperBound - reveal.lowerBound)
    }

    /// The star that lands when `stage`'s side closes, and how far it has landed at `q`.
    func sealStarAmount(starIndex: Int, starReveal: Double, q: Double, p: Double) -> Double {
        for stage in [FWSealStage.signed, .sent, .accepted] where seal.stars[stage.name] == starIndex {
            return Self.clamp01((q - stage.q + 0.25) / 0.25)
        }
        return q >= 4 ? Self.strokeProgress((starReveal - 0.04) ... (starReveal + 0.03), p) : 0
    }
}

// MARK: - The loader and the mirror

extension FWShikiban {
    /// Where the loader's comets are at `seconds`: (head, tail) turns each, clockwise from 12 o'clock.
    func loaderComets(_ seconds: Double) -> [(head: Double, tail: Double)] {
        let head = (seconds / loader.secondsPerTurn).truncatingRemainder(dividingBy: 1)
        return (0 ..< loader.comets).map { index in
            let turn = (head + Double(index) / Double(loader.comets)).truncatingRemainder(dividingBy: 1)
            return (turn, turn - loader.tailTurn)
        }
    }

    /// A point on the mirror's rim (unit radius) at `turn`, clockwise from 12 o'clock. Each lobe is a quarter of its
    /// circle and covers an eighth of a turn, so arc length is linear in the turn.
    func rimPoint(_ turn: Double) -> CGPoint {
        let t = (turn.truncatingRemainder(dividingBy: 1) + 1).truncatingRemainder(dividingBy: 1)
        let lobes = Double(mirror.lobes)
        let shifted = (t + 1 / (2 * lobes)).truncatingRemainder(dividingBy: 1)
        let lobe = floor(shifted * lobes)
        let within = shifted * lobes - lobe
        let direction = lobe / lobes * 2 * .pi
        let centre = CGPoint(x: sin(direction) * mirror.lobeCentre, y: -cos(direction) * mirror.lobeCentre)
        let out = -Double.pi / 2 + direction
        let angle = out - .pi / 4 + within * (.pi / 2)
        return CGPoint(x: centre.x + CGFloat(cos(angle) * mirror.lobeRadius), y: centre.y + CGFloat(sin(angle) * mirror.lobeRadius))
    }

    /// The rim from `from` to `to` turns (may run past 1), sampled finely enough to read as arcs.
    func rimPath(center: CGPoint, radius: CGFloat, from: Double = 0, to: Double = 1) -> UIBezierPath {
        let path = UIBezierPath()
        let steps = max(8, Int(ceil(abs(to - from) * 192)))
        for step in 0 ... steps {
            let point = rimPoint(from + (to - from) * Double(step) / Double(steps))
            let position = CGPoint(x: center.x + point.x * radius, y: center.y + point.y * radius)
            if step == 0 { path.move(to: position) } else { path.addLine(to: position) }
        }
        return path
    }

    /// The closed eight-lobed rim from the kit's arcs.
    func mirrorRimPath(center: CGPoint, radius: CGFloat) -> UIBezierPath {
        let path = UIBezierPath()
        for (index, arc) in mirror.rim.enumerated() {
            let lobeCenter = CGPoint(x: center.x + CGFloat(arc.cx) * radius, y: center.y + CGFloat(arc.cy) * radius)
            let start = CGPoint(
                x: lobeCenter.x + CGFloat(cos(arc.from) * arc.r) * radius,
                y: lobeCenter.y + CGFloat(sin(arc.from) * arc.r) * radius
            )
            if index == 0 { path.move(to: start) } else { path.addLine(to: start) }
            path.addArc(
                withCenter: lobeCenter, radius: CGFloat(arc.r) * radius,
                startAngle: CGFloat(arc.from), endAngle: CGFloat(arc.to), clockwise: true
            )
        }
        path.close()
        return path
    }

    /// The asanoha lattice over `rect`, cell width `cell` points.
    func asanohaPath(in rect: CGRect, cell: CGFloat) -> UIBezierPath {
        let path = UIBezierPath()
        guard cell > 0, rect.width > 0, rect.height > 0 else { return path }
        let tileHeight = CGFloat(asanoha.height) * cell
        var y = rect.minY
        while y < rect.maxY {
            var x = rect.minX
            while x < rect.maxX {
                for line in asanoha.lines where line.count == 4 {
                    path.move(to: CGPoint(x: x + CGFloat(line[0]) * cell, y: y + CGFloat(line[1]) * cell))
                    path.addLine(to: CGPoint(x: x + CGFloat(line[2]) * cell, y: y + CGFloat(line[3]) * cell))
                }
                x += cell * CGFloat(asanoha.width)
            }
            y += tileHeight
        }
        return path
    }
}

/// The stage a transfer's seal reached and when, so the send success screen continues the same figure.
final class FWSealRecord {
    static let shared = FWSealRecord()

    private(set) var stage: FWSealStage = .idle
    private(set) var time: TimeInterval = 0
    /// A stage older than this belongs to an earlier transfer.
    static let freshness: TimeInterval = 30

    /// A new transfer: nothing drawn yet.
    func begin(now: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        stage = .idle
        time = now
    }

    /// The figure has drawn `stage`. A stage never goes back within one transfer.
    func note(_ stage: FWSealStage, now: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        if stage > self.stage || time == 0 || now - time > Self.freshness {
            self.stage = stage
        }
        time = now
    }

    func reset() {
        stage = .idle
        time = 0
    }

    /// The stage the last transfer's figure reached, or nil when there is no recent transfer.
    func recent(now: TimeInterval = ProcessInfo.processInfo.systemUptime) -> FWSealStage? {
        time > 0 && now - time <= Self.freshness ? stage : nil
    }
}
