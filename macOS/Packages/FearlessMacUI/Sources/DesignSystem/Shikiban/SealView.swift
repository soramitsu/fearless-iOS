import SwiftUI

/// How far a submitted transfer has got. Each stage is lit only when the
/// app knows it happened.
public enum SealStage: Int, Sendable, Comparable, CaseIterable {
    /// Nothing submitted yet.
    case idle
    /// The user approved; the app is preparing to sign.
    case ready
    /// The transaction is signed.
    case signed
    /// It was handed to a node (broadcast).
    case sent
    /// The network included it in a block.
    case accepted
    /// It is final.
    case finalized

    public static func < (lhs: SealStage, rhs: SealStage) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Words VoiceOver reads for the stage.
    public var spokenDescription: String {
        switch self {
        case .idle: return "Not started"
        case .ready: return "Preparing to sign"
        case .signed: return "Signed"
        case .sent: return "Sent to the network"
        case .accepted: return "Included in a block"
        case .finalized: return "Final"
        }
    }
}

/// The transfer seal: the kit's solar geometry drawn by what has actually
/// happened. Rings appear when the transfer is approved, one side of the
/// upward triangle for each of signed, sent and included, and the whole
/// figure ignites in gold when the transfer is final. A cyan comet runs the
/// stroke that comes next while the app waits. Failure turns the figure
/// ember and lets it fall apart. With Reduce Motion the strokes of the
/// stages reached are shown without moving.
public struct SealView: View {
    private let stage: SealStage
    private let failed: Bool
    private let uncertain: Bool
    private let size: CGFloat

    @MotionAllowed private var motionAllowed
    @State private var clock = SealClock()
    @State private var settled = false

    /// - Parameters:
    ///   - failed: the network definitively rejected the transfer.
    ///   - uncertain: the transfer was sent but its outcome could not be
    ///     confirmed. The strokes reached stay, in a neutral colour that is
    ///     neither gold (final) nor ember (failed), and nothing moves.
    public init(stage: SealStage, failed: Bool = false, uncertain: Bool = false, size: CGFloat = 176) {
        self.stage = stage
        self.failed = failed
        self.uncertain = uncertain && !failed
        self.size = size
    }

    public var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [BrandPalette.plum.opacity(0.9), BrandPalette.night, BrandPalette.ink],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.5
                    )
                )
            Circle().strokeBorder(BrandPalette.gold.opacity(0.22), lineWidth: 1)
            if motionAllowed {
                TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: settled || stage == .idle)) { timeline in
                    Canvas { context, canvasSize in
                        SealRenderer(stage: stage, failed: failed, uncertain: uncertain, clock: clock, now: timeline.date, animated: true)
                            .draw(in: &context, size: canvasSize)
                    }
                }
            } else {
                Canvas { context, canvasSize in
                    SealRenderer(stage: stage, failed: failed, clock: clock, now: .distantFuture, animated: false)
                        .draw(in: &context, size: canvasSize)
                }
            }
        }
        .frame(width: size, height: size)
        .onAppear { clock.adopt(stage: stage, failed: failed, at: Date(), alreadyReached: true) }
        .onChange(of: stage) { _, newValue in clock.adopt(stage: newValue, failed: failed, at: Date(), alreadyReached: false) }
        .onChange(of: failed) { _, newValue in clock.adopt(stage: stage, failed: newValue, at: Date(), alreadyReached: false) }
        .task(id: stage.rawValue * 4 + (failed ? 1 : 0) + (uncertain ? 2 : 0)) {
            // Stop redrawing once the figure is final, broken or left unconfirmed and its last stroke has landed.
            settled = false
            guard failed || uncertain || stage == .finalized else { return }
            try? await Task.sleep(for: .seconds(1.8))
            if !Task.isCancelled { settled = true }
        }
        .accessibilityElement()
        .accessibilityLabel("Transfer progress")
        .accessibilityValue(failed ? "Failed" : (uncertain ? "Sent, confirmation unknown" : stage.spokenDescription))
    }
}

/// When each stage was reached, so strokes can draw over their own time.
struct SealClock: Equatable {
    private(set) var reachedAt: [SealStage: Date] = [:]
    private(set) var failedAt: Date?

    /// Records newly reached stages. Stages that were already reached when
    /// the view appeared are drawn complete; several stages arriving at once
    /// draw one after another, 180 ms apart.
    mutating func adopt(stage: SealStage, failed: Bool, at now: Date, alreadyReached: Bool) {
        var offset: TimeInterval = 0
        for candidate in SealStage.allCases where candidate != .idle && candidate <= stage {
            if reachedAt[candidate] == nil {
                reachedAt[candidate] = alreadyReached ? .distantPast : now.addingTimeInterval(offset)
                offset += BrandMotion.d180
            }
        }
        if failed, failedAt == nil {
            failedAt = alreadyReached ? .distantPast : now
        }
        if !failed { failedAt = nil }
    }

}

/// Draws one frame of the seal.
struct SealRenderer {
    let stage: SealStage
    let failed: Bool
    var uncertain = false
    let clock: SealClock
    let now: Date
    let animated: Bool

    /// True while the app is still waiting for the next stage.
    private var inFlight: Bool {
        !failed && !uncertain && stage != .idle && stage != .finalized
    }

    func draw(in context: inout GraphicsContext, size: CGSize) {
        guard stage != .idle else { return }
        let centre = CGPoint(x: size.width / 2, y: size.height / 2)
        let scale = min(size.width, size.height) / 2 * 0.80
        let core = failed ? BrandPalette.failure : (uncertain ? BrandPalette.textMuted : BrandPalette.sealCore)
        let glow = failed ? BrandPalette.failure : (uncertain ? BrandPalette.line : BrandPalette.sealGlow)
        let breakProgress = failureProgress

        var drawn: [(path: Path, weight: CGFloat, alpha: Double)] = []
        for (index, stroke) in SolarGeometry.strokes.enumerated() {
            let fraction = drawFraction(index: index, stroke: stroke)
            guard fraction > 0.001 else { continue }
            var path = ShikibanGeometry.path(for: stroke, centre: centre, scale: scale)
            if fraction < 1 { path = path.trimmedPath(from: 0, to: fraction) }
            var alpha = 1.0
            if breakProgress > 0 {
                let drop = scale * (0.05 + 0.15 * Self.unitNoise(index)) * breakProgress
                path = path.offsetBy(dx: (Self.unitNoise(index &+ 17) - 0.5) * scale * 0.06 * breakProgress, dy: drop)
                alpha = 1 - 0.35 * breakProgress
            }
            drawn.append((path, stroke.weight, alpha))
        }

        // Soft glow under a bright core, additive.
        let glowWidth = max(2, scale * SolarGeometry.glowWidth)
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: glowWidth * 0.9))
            layer.blendMode = .plusLighter
            for item in drawn {
                layer.stroke(item.path, with: .color(glow.opacity(0.55 * item.alpha * glowStrength)), style: StrokeStyle(lineWidth: glowWidth * item.weight, lineCap: .round))
            }
        }
        let coreWidth = max(1, scale * SolarGeometry.coreWidth * 2.2)
        for item in drawn {
            context.stroke(item.path, with: .color(core.opacity(item.alpha)), style: StrokeStyle(lineWidth: coreWidth * item.weight, lineCap: .round))
        }

        drawTicks(in: &context, centre: centre, scale: scale, color: core)
        if !uncertain {
            drawStars(in: &context, centre: centre, scale: scale)
        }
        if inFlight || uncertain {
            // Unconfirmed: the stroke that never came stays a dashed trace, without a comet.
            drawComet(in: &context, centre: centre, scale: scale)
        }
    }

    // MARK: Progress

    private func elapsed(since stage: SealStage) -> TimeInterval? {
        guard let date = clock.reachedAt[stage] else { return nil }
        return now.timeIntervalSince(date)
    }

    private func stageFraction(_ stage: SealStage) -> Double {
        guard self.stage >= stage else { return 0 }
        guard animated, let elapsed = elapsed(since: stage) else { return 1 }
        return ShikibanGeometry.settle(elapsed / ShikibanTokens.sealStageSeconds)
    }

    /// Progress of the final ignite, from the seal's accepted share to 1.
    private var igniteProgress: Double {
        guard stage == .finalized else { return 0 }
        guard animated, let elapsed = elapsed(since: .finalized) else { return 1 }
        return 0.41 + 0.59 * ShikibanGeometry.settle(elapsed / ShikibanTokens.sealIgniteSeconds)
    }

    private var failureProgress: Double {
        guard failed else { return 0 }
        guard animated, let failedAt = clock.failedAt else { return 1 }
        return ShikibanGeometry.settle(now.timeIntervalSince(failedAt) / ShikibanTokens.sealBreakSeconds)
    }

    /// The glow eases back once the figure is final and at rest.
    private var glowStrength: Double {
        guard stage == .finalized, !failed else { return 1 }
        guard animated, let elapsed = elapsed(since: .finalized) else { return 0.6 }
        let rest = min(1, max(0, (elapsed - ShikibanTokens.sealIgniteSeconds) / 0.7))
        return 1.25 - 0.65 * rest
    }

    private func drawFraction(index: Int, stroke: SolarStroke) -> Double {
        if SolarGeometry.ringIndices.contains(index) { return stageFraction(.ready) }
        if let side = SolarGeometry.hexagramIndices.firstIndex(of: index), side < 3 {
            return stageFraction([SealStage.signed, .sent, .accepted][side])
        }
        let progress = igniteProgress
        guard progress > 0 else { return 0 }
        let window = max(0.0001, Double(stroke.revealEnd - stroke.revealStart))
        return min(1, max(0, (progress - Double(stroke.revealStart)) / window))
    }

    // MARK: Parts

    private func drawTicks(in context: inout GraphicsContext, centre: CGPoint, scale: CGFloat, color: Color) {
        let appear = stageFraction(.ready)
        guard appear > 0 else { return }
        let seconds = animated ? now.timeIntervalSinceReferenceDate : 0
        let turns = seconds * SolarGeometry.tickTurnsPerSecond * (inFlight ? 14 : 1)
        let radius = max(0.5, scale * SolarGeometry.tickSize * 1.4)
        var dots = Path()
        for tick in 0..<SolarGeometry.tickCount {
            let angle = 2 * Double.pi * (Double(tick) / Double(SolarGeometry.tickCount) + turns)
            let p = ShikibanGeometry.point(
                SolarGeometry.tickRadius * CGFloat(cos(angle)),
                SolarGeometry.tickRadius * CGFloat(sin(angle)),
                centre: centre,
                scale: scale
            )
            dots.addEllipse(in: CGRect(x: p.x - radius, y: p.y - radius, width: radius * 2, height: radius * 2))
        }
        context.fill(dots, with: .color(color.opacity(0.75 * appear * (failed ? 0.5 : 1))))
    }

    private func drawStars(in context: inout GraphicsContext, centre: CGPoint, scale: CGFloat) {
        guard !failed else { return }
        let ignite = igniteProgress
        for (index, star) in SolarGeometry.stars.enumerated() {
            var strength = 0.0
            if index == ShikibanTokens.sealStarSigned { strength = max(strength, stageFraction(.signed)) }
            if index == ShikibanTokens.sealStarSent { strength = max(strength, stageFraction(.sent)) }
            if index == ShikibanTokens.sealStarAccepted { strength = max(strength, stageFraction(.accepted)) }
            if ignite > 0, ignite >= Double(star.reveal) { strength = 1 }
            guard strength > 0.01 else { continue }
            let p = ShikibanGeometry.point(star.x, star.y, centre: centre, scale: scale)
            let halo = scale * star.size * 0.42
            context.drawLayer { layer in
                layer.blendMode = .plusLighter
                layer.fill(
                    Path(ellipseIn: CGRect(x: p.x - halo, y: p.y - halo, width: halo * 2, height: halo * 2)),
                    with: .radialGradient(
                        Gradient(colors: [BrandPalette.sealStar.opacity(0.75 * strength), BrandPalette.sealGlow.opacity(0.18 * strength), .clear]),
                        center: p,
                        startRadius: 0,
                        endRadius: halo
                    )
                )
            }
            let arm = max(1.5, scale * star.size * 0.2) * strength
            var sparkle = Path()
            sparkle.move(to: CGPoint(x: p.x, y: p.y - arm))
            sparkle.addQuadCurve(to: CGPoint(x: p.x + arm, y: p.y), control: p)
            sparkle.addQuadCurve(to: CGPoint(x: p.x, y: p.y + arm), control: p)
            sparkle.addQuadCurve(to: CGPoint(x: p.x - arm, y: p.y), control: p)
            sparkle.addQuadCurve(to: CGPoint(x: p.x, y: p.y - arm), control: p)
            context.fill(sparkle, with: .color(BrandPalette.sealStar.opacity(strength)))
        }
    }

    /// The stroke the transfer is waiting on: a faint dashed trace and, when
    /// motion is allowed, a cyan comet running along it.
    private func drawComet(in context: inout GraphicsContext, centre: CGPoint, scale: CGFloat) {
        let nextIndex: Int
        switch stage {
        case .ready: nextIndex = SolarGeometry.hexagramIndices[0]
        case .signed: nextIndex = SolarGeometry.hexagramIndices[1]
        case .sent: nextIndex = SolarGeometry.hexagramIndices[2]
        case .accepted: nextIndex = SolarGeometry.hexagramIndices[3]
        case .idle, .finalized: return
        }
        let path = ShikibanGeometry.path(for: SolarGeometry.strokes[nextIndex], centre: centre, scale: scale)
        let width = max(1, scale * SolarGeometry.coreWidth * 2.2)
        let trace = uncertain ? BrandPalette.textMuted.opacity(0.45) : BrandPalette.cyan.opacity(0.32)
        context.stroke(path, with: .color(trace), style: StrokeStyle(lineWidth: width, lineCap: .round, dash: [3, 5]))
        guard animated, !uncertain else { return }
        let phase = now.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: ShikibanTokens.sealCometSeconds) / ShikibanTokens.sealCometSeconds
        let head = phase * 1.3
        let tail = 0.3
        let pieces = 8
        context.drawLayer { layer in
            layer.blendMode = .plusLighter
            for piece in 0..<pieces {
                let from = head - tail * Double(pieces - piece) / Double(pieces)
                let to = head - tail * Double(pieces - piece - 1) / Double(pieces)
                guard to > 0, from < 1 else { continue }
                let segment = path.trimmedPath(from: max(0, from), to: min(1, to))
                let alpha = Double(piece + 1) / Double(pieces)
                layer.stroke(segment, with: .color(BrandPalette.cyan.opacity(alpha)), style: StrokeStyle(lineWidth: width * 1.6, lineCap: .round))
            }
        }
    }

    /// Deterministic 0...1 value per stroke, so the break looks the same every time.
    private static func unitNoise(_ index: Int) -> Double {
        var value = UInt32(truncatingIfNeeded: index &* 374_761_393 &+ 668_265_263)
        value = (value ^ (value >> 13)) &* 1_274_126_177
        return Double((value ^ (value >> 16)) % 1000) / 1000
    }
}
