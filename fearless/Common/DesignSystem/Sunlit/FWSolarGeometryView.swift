import UIKit

/// The solar geometry behind the crow (rings, hexagram, lattice of circles), from the kit's `solar-geometry.json`.
/// Units: the outer ring has radius 1, origin at the centre, y down. Each stroke draws over its `reveal` window of the
/// ignite's progress; circles start at 12 o'clock and run anticlockwise.
struct FWSolarGeometry: Decodable, Equatable {
    struct Stroke: Decodable, Equatable {
        let type: String
        let group: String
        let x1: Double?
        let y1: Double?
        let x2: Double?
        let y2: Double?
        let cx: Double?
        let cy: Double?
        let r: Double?
        let weight: Double
        let reveal: [Double]

        var revealStart: Double { reveal.first ?? 0 }
        var revealEnd: Double { reveal.last ?? 1 }

        /// The stroke's path at `radius` points around `center`.
        func path(center: CGPoint, radius: CGFloat) -> UIBezierPath? {
            switch type {
            case "circle":
                guard let cx, let cy, let r else { return nil }
                let start = -CGFloat.pi / 2
                return UIBezierPath(
                    arcCenter: CGPoint(x: center.x + CGFloat(cx) * radius, y: center.y + CGFloat(cy) * radius),
                    radius: CGFloat(r) * radius,
                    startAngle: start,
                    endAngle: start - 2 * .pi,
                    clockwise: false
                )
            case "line":
                guard let x1, let y1, let x2, let y2 else { return nil }
                let path = UIBezierPath()
                path.move(to: CGPoint(x: center.x + CGFloat(x1) * radius, y: center.y + CGFloat(y1) * radius))
                path.addLine(to: CGPoint(x: center.x + CGFloat(x2) * radius, y: center.y + CGFloat(y2) * radius))
                return path
            default:
                return nil
            }
        }
    }

    struct StrokeWidths: Decodable, Equatable {
        let core: Double
        let glow: Double
    }

    struct Colors: Decodable, Equatable {
        let core: String
        let glow: String
        let star: String
    }

    struct Ticks: Decodable, Equatable {
        let count: Int
        let r: Double
        let size: Double
        let appearsAt: Double
        let turnsPerSecond: Double
    }

    struct Star: Decodable, Equatable {
        let x: Double
        let y: Double
        let size: Double
        let reveal: Double
    }

    let formatVersion: Int
    let stroke: StrokeWidths
    let colors: Colors
    let strokes: [Stroke]
    let ticks: Ticks
    let stars: [Star]

    static let bundled: FWSolarGeometry? = {
        guard let url = Bundle.main.url(forResource: "solar-geometry", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(FWSolarGeometry.self, from: data)
    }()

    /// The `#RRGGBB` colours of the file, as sRGB.
    static func color(_ hex: String) -> UIColor {
        let digits = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        return FWSunlit.color(UInt32(digits, radix: 16) ?? 0xFFC24A)
    }
}

/// Draws the solar geometry and ignites it: every stroke draws over its window of the ignite, the core over a soft
/// glow, the stars pop in at their moments, and the tick ring turns slowly. Decorative: hidden from assistive
/// technologies. Reduced motion shows the finished figure.
///
/// Kit v4 adds two uses. The seal: the figure drawn by a transfer's stages (`showSeal`, `advanceSeal`, `breakSeal`),
/// with a cyan comet on the stroke the transfer waits for. The heaven plate: while the wallet syncs, the tick ring
/// turns 14 times faster and the figure brightens by half again (`setHeavenPlate`).
final class FWSolarGeometryView: UIView {
    /// How strongly each group shows, 0–1. The sky card keeps the lattice faint behind its text.
    var groupOpacity: [String: Float] = [:] {
        didSet { setNeedsLayout() }
    }

    /// The outer ring's radius as a fraction of half the view's shorter side.
    var radiusFraction: CGFloat = 0.94 {
        didSet { setNeedsLayout() }
    }

    /// The figure's centre in the view's coordinates; the view's centre when nil.
    var focus: CGPoint? {
        didSet { setNeedsLayout() }
    }

    private let geometry: FWSolarGeometry?
    private let effects: FWEffects
    private let tokens: FWShikiban?
    private let content = CALayer()
    private let tickLayer = CAShapeLayer()
    private var strokeLayers: [(stroke: FWSolarGeometry.Stroke, core: CAShapeLayer, glow: CAShapeLayer)] = []
    private var groupIndices: [Int] = []
    private var starLayers: [(star: FWSolarGeometry.Star, layer: CALayer)] = []
    private(set) var isIgnited = false
    private var turning = false

    init(geometry: FWSolarGeometry? = .bundled, effects: FWEffects = .shared, tokens: FWShikiban? = .bundled) {
        self.geometry = geometry
        self.effects = effects
        self.tokens = tokens
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        accessibilityElementsHidden = true
        backgroundColor = .clear
        layer.addSublayer(content)
        buildLayers()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var radius: CGFloat {
        min(bounds.width, bounds.height) / 2 * radiusFraction
    }

    private var figureCenter: CGPoint {
        focus ?? CGPoint(x: bounds.midX, y: bounds.midY)
    }

    private func buildLayers() {
        guard let geometry else { return }
        let core = FWSolarGeometry.color(geometry.colors.core)
        let glow = FWSolarGeometry.color(geometry.colors.glow)
        var counts: [String: Int] = [:]
        for stroke in geometry.strokes {
            let glowLayer = CAShapeLayer()
            glowLayer.fillColor = nil
            glowLayer.strokeColor = glow.withAlphaComponent(0.32).cgColor
            glowLayer.lineCap = .round
            let coreLayer = CAShapeLayer()
            coreLayer.fillColor = nil
            coreLayer.strokeColor = core.cgColor
            coreLayer.lineCap = .round
            content.addSublayer(glowLayer)
            content.addSublayer(coreLayer)
            strokeLayers.append((stroke, coreLayer, glowLayer))
            groupIndices.append(counts[stroke.group, default: 0])
            counts[stroke.group, default: 0] += 1
        }
        tickLayer.fillColor = core.withAlphaComponent(0.85).cgColor
        tickLayer.strokeColor = nil
        content.addSublayer(tickLayer)
        let starImage = Self.starImage(color: FWSolarGeometry.color(geometry.colors.star), glow: glow)
        for star in geometry.stars {
            let layer = CALayer()
            layer.contents = starImage.cgImage
            layer.compositingFilter = "screenBlendMode"
            content.addSublayer(layer)
            starLayers.append((star, layer))
        }
        let flight = FWShikiban.color(tokens?.colors.flight ?? "#38E8E0")
        cometTrace.fillColor = nil
        cometTrace.strokeColor = flight.withAlphaComponent(0.22).cgColor
        cometTrace.lineCap = .round
        cometTrace.isHidden = true
        content.addSublayer(cometTrace)
        cometHead.contents = Self.cometImage(color: flight).cgImage
        cometHead.compositingFilter = "screenBlendMode"
        cometHead.isHidden = true
        content.addSublayer(cometHead)
        setProgress(1)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let geometry else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        content.frame = bounds
        let center = figureCenter
        let radius = radius
        for (stroke, core, glow) in strokeLayers {
            let path = stroke.path(center: center, radius: radius)?.cgPath
            core.path = path
            glow.path = path
            core.lineWidth = max(0.6, CGFloat(geometry.stroke.core * stroke.weight) * radius * 2)
            glow.lineWidth = max(2, CGFloat(geometry.stroke.glow * stroke.weight) * radius)
        }
        let ticks = UIBezierPath()
        let dot = max(0.5, CGFloat(geometry.ticks.size) * radius)
        for index in 0 ..< geometry.ticks.count {
            let angle = CGFloat(index) / CGFloat(geometry.ticks.count) * 2 * .pi
            let point = CGPoint(
                x: center.x + cos(angle) * CGFloat(geometry.ticks.r) * radius,
                y: center.y + sin(angle) * CGFloat(geometry.ticks.r) * radius
            )
            ticks.append(UIBezierPath(ovalIn: CGRect(x: point.x - dot, y: point.y - dot, width: dot * 2, height: dot * 2)))
        }
        tickLayer.bounds = bounds
        tickLayer.position = center
        tickLayer.anchorPoint = CGPoint(x: center.x / max(1, bounds.width), y: center.y / max(1, bounds.height))
        tickLayer.frame = bounds
        tickLayer.path = ticks.cgPath
        for (star, layer) in starLayers {
            let side = CGFloat(star.size) * radius
            layer.bounds = CGRect(x: 0, y: 0, width: side, height: side)
            layer.position = CGPoint(x: center.x + CGFloat(star.x) * radius, y: center.y + CGFloat(star.y) * radius)
        }
        cometTrace.frame = bounds
        let head = radius * 0.15
        cometHead.bounds = CGRect(x: 0, y: 0, width: head, height: head)
        applyOpacities()
        if sealMode {
            cometStroke = nil
            applySeal()
        }
        CATransaction.commit()
    }

    /// Each group's opacity, brightened while the wallet syncs (the heaven plate), never past 1.
    private func applyOpacities() {
        let boost = brightness
        func strength(_ value: Float) -> Float { min(1, value * boost) }
        for (stroke, core, glow) in strokeLayers {
            let opacity = strength(groupOpacity[stroke.group] ?? 1)
            core.opacity = opacity
            glow.opacity = opacity
        }
        let tickBase = strength(groupOpacity["ticks"] ?? groupOpacity["ring"] ?? 1)
        tickLayer.opacity = sealMode ? tickBase * Float(FWShikiban.clamp01(sealQ)) : tickBase
        for (_, layer) in starLayers {
            layer.opacity = strength(groupOpacity["stars"] ?? 1)
        }
    }

    /// Shows the figure as it stands at `progress` (0–1) of the ignite, without animation.
    func setProgress(_ progress: Double) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (stroke, core, glow) in strokeLayers {
            let span = max(0.0001, stroke.revealEnd - stroke.revealStart)
            let end = CGFloat(min(1, max(0, (progress - stroke.revealStart) / span)))
            core.strokeEnd = end
            glow.strokeEnd = end
        }
        if let ticks = geometry?.ticks {
            tickLayer.isHidden = progress < ticks.appearsAt
        }
        for (star, layer) in starLayers {
            layer.isHidden = progress < star.reveal
        }
        CATransaction.commit()
    }

    /// Ignites the figure over `duration`, then lets it settle to `settleOpacity`. Reduced motion shows the
    /// finished figure at once.
    func ignite(duration: TimeInterval = 0.9, settleOpacity: Float = 0.25, settleAfter: TimeInterval = 0.35) {
        isIgnited = true
        layer.removeAllAnimations()
        guard case .full = FWMotionPolicy.current(effects: effects).style(for: .txSuccess) else {
            setProgress(1)
            alpha = CGFloat(settleOpacity)
            return
        }
        alpha = 1
        setProgress(0)
        let now = CACurrentMediaTime()
        for (stroke, core, glow) in strokeLayers {
            let draw = CABasicAnimation(keyPath: "strokeEnd")
            draw.fromValue = 0
            draw.toValue = 1
            draw.beginTime = now + stroke.revealStart * duration
            draw.duration = max(0.04, (stroke.revealEnd - stroke.revealStart) * duration)
            draw.fillMode = .both
            draw.isRemovedOnCompletion = false
            draw.timingFunction = CAMediaTimingFunction(name: .easeOut)
            core.strokeEnd = 1
            glow.strokeEnd = 1
            core.add(draw, forKey: "fw.ignite")
            glow.add(draw, forKey: "fw.ignite")
        }
        if let ticks = geometry?.ticks {
            tickLayer.isHidden = false
            let appear = CABasicAnimation(keyPath: "opacity")
            appear.fromValue = 0
            appear.toValue = tickLayer.opacity
            appear.beginTime = now + ticks.appearsAt * duration
            appear.duration = 0.25
            appear.fillMode = .backwards
            tickLayer.add(appear, forKey: "fw.ignite")
        }
        for (star, layer) in starLayers {
            layer.isHidden = false
            let pop = CAKeyframeAnimation(keyPath: "transform.scale")
            pop.values = [0.01, 1.35, 1]
            pop.keyTimes = [0, 0.55, 1]
            pop.beginTime = now + star.reveal * duration
            pop.duration = 0.3
            pop.fillMode = .backwards
            layer.add(pop, forKey: "fw.ignite")
        }
        UIView.animate(
            withDuration: 0.6, delay: duration + settleAfter, options: [.curveEaseInOut, .allowUserInteraction]
        ) {
            self.alpha = CGFloat(settleOpacity)
        }
    }

    /// Turns the tick ring slowly at the kit's rate, while motion is allowed. Stops when `false`.
    func setTurning(_ turning: Bool) {
        guard turning != self.turning else { return }
        self.turning = turning
        tickLayer.removeAnimation(forKey: "fw.turn")
        guard turning, let rate = geometry?.ticks.turnsPerSecond, rate != 0,
              !FWMotionPolicy.current(effects: effects).isRestricted else { return }
        let spin = CABasicAnimation(keyPath: "transform.rotation.z")
        spin.fromValue = 0
        spin.toValue = rate < 0 ? -2 * Double.pi : 2 * Double.pi
        spin.duration = 1 / abs(rate)
        spin.repeatCount = .infinity
        spin.isRemovedOnCompletion = false
        tickLayer.add(spin, forKey: "fw.turn")
    }

    var isTurning: Bool {
        tickLayer.animation(forKey: "fw.turn") != nil
    }

    // MARK: - The heaven plate (kit v4 part 2)

    /// The tick ring's speed as a multiple of `ticks.turnsPerSecond`, and the figure's brightness factor.
    private(set) var turnBoost: Double = 1
    private(set) var brightness: Float = 1
    private var plateLink: CADisplayLink?
    private var plateFrom: (boost: Double, brightness: Float) = (1, 1)
    private var plateTo: (boost: Double, brightness: Float) = (1, 1)
    private var plateElapsed: Double = 0
    private var plateLastTimestamp: CFTimeInterval?
    static let syncTurnBoost = 14.0
    static let syncBrightness: Float = 1.5

    /// While the wallet syncs the heaven plate turns 14 times faster and the figure brightens by half again; both ease
    /// back over 720 ms when the sync settles. Reduced motion changes the brightness only, at once.
    func setHeavenPlate(syncing: Bool, animated: Bool) {
        let target: (boost: Double, brightness: Float) = syncing ? (Self.syncTurnBoost, Self.syncBrightness) : (1, 1)
        guard target != plateTo else { return }
        plateTo = target
        let restricted = FWMotionPolicy.current(effects: effects).isRestricted
        guard animated, !restricted, window != nil else {
            stopPlateLink()
            applyPlate(boost: target.boost, brightness: target.brightness)
            return
        }
        plateFrom = (turnBoost, brightness)
        plateElapsed = 0
        plateLastTimestamp = nil
        if plateLink == nil {
            let link = CADisplayLink(target: FWWeakLinkTarget { [weak self] link in self?.stepPlate(link) }, selector: #selector(FWWeakLinkTarget.tick(_:)))
            link.add(to: .main, forMode: .common)
            plateLink = link
        }
    }

    private func stepPlate(_ link: CADisplayLink) {
        let delta = plateLastTimestamp.map { min(link.timestamp - $0, 1.0 / 20) * 1000 } ?? 0
        plateLastTimestamp = link.timestamp
        plateElapsed += delta
        let duration = (tokens?.durationsMs.count ?? 0) > 6 ? tokens?.durationsMs[6] ?? 720 : 720
        let local = FWShikiban.clamp01(plateElapsed / duration)
        let eased = tokens.map { FWShikiban.bezier($0.easing.glide)(local) } ?? local
        applyPlate(
            boost: plateFrom.boost + (plateTo.boost - plateFrom.boost) * eased,
            brightness: plateFrom.brightness + (plateTo.brightness - plateFrom.brightness) * Float(eased)
        )
        if local >= 1 { stopPlateLink() }
    }

    private func stopPlateLink() {
        plateLink?.invalidate()
        plateLink = nil
    }

    private func applyPlate(boost: Double, brightness: Float) {
        turnBoost = boost
        self.brightness = brightness
        // Re-anchor the ring's clock so a new speed carries on from the angle it shows now.
        let now = tickLayer.superlayer?.convertTime(CACurrentMediaTime(), from: nil) ?? CACurrentMediaTime()
        let local = tickLayer.convertTime(CACurrentMediaTime(), from: nil)
        tickLayer.beginTime = now
        tickLayer.timeOffset = local
        tickLayer.speed = Float(boost)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        applyOpacities()
        CATransaction.commit()
    }

    // MARK: - The seal (kit v4 part 3)

    private let cometTrace = CAShapeLayer()
    private let cometHead = CALayer()
    private var cometStroke: Int?
    private var sealMode = false
    private var sealTarget: FWSealStage = .idle
    private(set) var sealQ: Double = 0
    private(set) var sealP: Double = 0
    private(set) var isSealBroken = false
    private var stepFrom: Double = -1
    private var stepElapsed: Double = 0
    private var igniteElapsed: Double = 0
    private var restElapsed: Double = 0
    private var sealLink: CADisplayLink?
    private var sealLastTimestamp: CFTimeInterval?
    /// The send success screen's figure rests at 25 % after the ignite.
    var sealRestsAfterIgnite = true
    /// The figure writes each stage it finishes drawing to `FWSealRecord`, for the success screen to continue.
    var recordsSealStages = false
    static let cometKey = "fw.seal.comet"

    private var sealIsRestricted: Bool {
        FWMotionPolicy.current(effects: effects).isRestricted
    }

    /// True while the figure still has drawing to do towards the stage it knows.
    var isSealAnimating: Bool {
        guard sealMode, !isSealBroken, let tokens else { return false }
        if sealQ < sealTarget.q - 1e-9 { return true }
        guard sealTarget == .accepted else { return false }
        return sealP < 1 - 1e-12 || (sealRestsAfterIgnite && restElapsed < tokens.seal.restMs)
    }

    /// Shows the figure at `stage` at once: the strokes of the stages reached, the rest of the ignite not yet drawn.
    func showSeal(stage: FWSealStage) {
        layer.removeAllAnimations()
        sealMode = true
        isSealBroken = false
        sealTarget = stage
        sealQ = stage.q
        sealP = tokens?.sealProgress(.accepted) ?? 0.41
        stepFrom = -1
        stepElapsed = 0
        igniteElapsed = 0
        restElapsed = 0
        alpha = 1
        if stage >= .ready { setTurning(true) }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        applyOpacities()
        applySeal()
        CATransaction.commit()
    }

    /// The transfer reached `stage`: its stroke draws over `seal.stageMs` with `easing.settle` (180 ms when a later
    /// stage is already known); acceptance then runs the rest of the ignite from 0.41 over `seal.igniteMs` and rests
    /// at 25 %. Reduced motion shows the strokes of the stages reached at once.
    func advanceSeal(to stage: FWSealStage) {
        if !sealMode { showSeal(stage: .idle) }
        // The same stage again only matters for acceptance, whose ignite may still be to run.
        guard !isSealBroken, stage > sealTarget || (stage == .accepted && isSealAnimating) else { return }
        sealTarget = stage
        if stage >= .ready { setTurning(true) }
        if sealIsRestricted {
            sealQ = stage.q
            if stage == .accepted {
                sealP = 1
                if sealRestsAfterIgnite, let tokens {
                    restElapsed = tokens.seal.restMs
                    alpha = CGFloat(tokens.seal.restStrength)
                }
            }
            noteDrawn()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            applyOpacities()
            applySeal()
            CATransaction.commit()
            return
        }
        startSealLinkIfNeeded()
    }

    /// Moves the seal's drawing on by `ms` (the display link calls this; tests call it directly).
    func stepSeal(byMs ms: Double) {
        guard sealMode, !isSealBroken, let tokens else { return }
        var remaining = ms
        var guardCount = 0
        let settle = tokens.settle
        while remaining > 0, guardCount < 32 {
            guardCount += 1
            if sealQ < sealTarget.q - 1e-9 {
                let from = floor(sealQ + 1e-9)
                if stepFrom != from {
                    stepFrom = from
                    stepElapsed = 0
                }
                let quick = sealTarget.q > from + 1
                let duration = quick && tokens.durationsMs.count > 2 ? tokens.durationsMs[2] : tokens.seal.stageMs
                let use = min(max(0, duration - stepElapsed), remaining)
                stepElapsed += use
                remaining -= use
                let local = FWShikiban.clamp01(stepElapsed / duration)
                sealQ = from + settle(local)
                if local >= 1 {
                    sealQ = from + 1
                    stepFrom = -1
                    noteDrawn()
                }
            } else if sealTarget == .accepted, sealP < 1 - 1e-12 {
                let accepted = tokens.sealProgress(.accepted)
                let use = min(max(0, tokens.seal.igniteMs - igniteElapsed), remaining)
                igniteElapsed += use
                remaining -= use
                let k = FWShikiban.clamp01(igniteElapsed / tokens.seal.igniteMs)
                sealP = k >= 1 ? 1 : accepted + (1 - accepted) * (1 - (1 - k) * (1 - k))
            } else if sealTarget == .accepted, sealRestsAfterIgnite, restElapsed < tokens.seal.restMs {
                let use = min(tokens.seal.restMs - restElapsed, remaining)
                restElapsed += use
                remaining -= use
                let share = FWShikiban.clamp01(restElapsed / tokens.seal.restMs)
                alpha = CGFloat(1 - (1 - tokens.seal.restStrength) * share)
            } else {
                break
            }
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        applyOpacities()
        applySeal()
        CATransaction.commit()
        if !isSealAnimating { stopSealLink() }
    }

    /// The transfer failed: the figure turns ember and falls apart over `seal.breakMs` (strokes drop by up to 0.2 of
    /// the radius and fade). Reduced motion turns it ember and fades it without the fall.
    func breakSeal(completion: (() -> Void)? = nil) {
        guard !isSealBroken else { return }
        isSealBroken = true
        stopSealLink()
        cometTrace.isHidden = true
        cometHead.isHidden = true
        cometHead.removeAnimation(forKey: Self.cometKey)
        tickLayer.isHidden = true
        starLayers.forEach { $0.layer.isHidden = true }
        let ember = FWShikiban.color(tokens?.colors.failure ?? "#FF5A4D")
        let duration = (tokens?.seal.breakMs ?? 510) / 1000
        let fall = Double(radius) * 0.2
        let restricted = sealIsRestricted
        CATransaction.begin()
        CATransaction.setCompletionBlock(completion)
        for (index, (_, core, glow)) in strokeLayers.enumerated() {
            core.strokeColor = ember.cgColor
            glow.strokeColor = ember.withAlphaComponent(0.32).cgColor
            let drop = restricted ? 0 : fall * (0.4 + Double((index * 37) % 10) / 10)
            for layer in [core, glow] {
                let fade = CABasicAnimation(keyPath: "opacity")
                fade.fromValue = layer.opacity
                fade.toValue = 0
                let move = CABasicAnimation(keyPath: "transform.translation.y")
                move.fromValue = 0
                move.toValue = drop
                let group = CAAnimationGroup()
                group.animations = [fade, move]
                group.duration = duration
                group.timingFunction = CAMediaTimingFunction(controlPoints: 0.55, 0, 1, 0.45)
                group.fillMode = .forwards
                group.isRemovedOnCompletion = false
                layer.add(group, forKey: "fw.seal.break")
            }
        }
        CATransaction.commit()
    }

    /// The drawn share of stroke `index` in `group` (model value), for tests and captures.
    func strokeEnd(group: String, index: Int) -> CGFloat? {
        guard let position = strokeLayers.indices.first(where: {
            strokeLayers[$0].stroke.group == group && groupIndices[$0] == index
        }) else { return nil }
        return strokeLayers[position].core.strokeEnd
    }

    private func noteDrawn() {
        guard recordsSealStages, let stage = FWSealStage(rawValue: Int(floor(sealQ + 1e-9))) else { return }
        FWSealRecord.shared.note(stage)
    }

    private func applySeal() {
        guard sealMode, let tokens else { return }
        for (position, (stroke, core, glow)) in strokeLayers.enumerated() {
            let reveal = stroke.revealStart ... max(stroke.revealStart, stroke.revealEnd)
            let amount = CGFloat(tokens.sealAmount(
                group: stroke.group, index: groupIndices[position], reveal: reveal, q: sealQ, p: sealP
            ))
            core.strokeEnd = amount
            glow.strokeEnd = amount
        }
        tickLayer.isHidden = isSealBroken || sealQ <= 0
        let starBase = min(1, (groupOpacity["stars"] ?? 1) * brightness)
        for (index, (star, layer)) in starLayers.enumerated() {
            let amount = tokens.sealStarAmount(starIndex: index, starReveal: star.reveal, q: sealQ, p: sealP)
            layer.isHidden = isSealBroken || amount <= 0
            layer.opacity = starBase * Float(amount)
            let scale = CGFloat(0.6 + 0.4 * amount)
            layer.setAffineTransform(CGAffineTransform(scaleX: scale, y: scale))
        }
        updateComet()
    }

    /// In flight: a cyan comet runs the stroke the transfer is waiting for, over a faint dashed trace of it.
    private func updateComet() {
        guard let tokens, let geometry else { return }
        let settled = floor(sealQ + 1e-6)
        let waiting = sealMode && !isSealBroken && sealTarget < .accepted && sealQ >= sealTarget.q - 1e-6
            && !sealIsRestricted && window != nil && bounds.width > 0
        let pendingRef: FWShikiban.StrokeRef? = settled == 0
            ? FWShikiban.StrokeRef(group: "ring", index: 0)
            : FWShikiban.StrokeRef(group: "hexagram", index: Int(settled) - 1)
        guard waiting, let ref = pendingRef, settled < 4,
              let position = strokeLayers.indices.first(where: {
                  strokeLayers[$0].stroke.group == ref.group && groupIndices[$0] == ref.index
              }),
              let path = strokeLayers[position].stroke.path(center: figureCenter, radius: radius)?.cgPath else {
            cometTrace.isHidden = true
            cometHead.isHidden = true
            cometHead.removeAnimation(forKey: Self.cometKey)
            cometStroke = nil
            return
        }
        guard cometStroke != position else { return }
        cometStroke = position
        let stroke = strokeLayers[position].stroke
        cometTrace.path = path
        cometTrace.lineWidth = max(0.6, CGFloat(geometry.stroke.core * stroke.weight) * radius * 1.5)
        cometTrace.lineDashPattern = [NSNumber(value: Double(radius * 0.02)), NSNumber(value: Double(radius * 0.045))]
        cometTrace.isHidden = false
        cometHead.isHidden = false
        let run = CAKeyframeAnimation(keyPath: "position")
        run.path = path
        run.calculationMode = .paced
        run.duration = tokens.seal.cometSeconds
        run.repeatCount = .infinity
        run.timingFunction = CAMediaTimingFunction(controlPoints: 0.33, 1, 0.68, 1)
        cometHead.add(run, forKey: Self.cometKey)
    }

    private func startSealLinkIfNeeded() {
        guard sealLink == nil, window != nil, isSealAnimating else { return }
        sealLastTimestamp = nil
        let link = CADisplayLink(target: FWWeakLinkTarget { [weak self] link in self?.stepSealLink(link) }, selector: #selector(FWWeakLinkTarget.tick(_:)))
        link.add(to: .main, forMode: .common)
        sealLink = link
    }

    private func stepSealLink(_ link: CADisplayLink) {
        let delta = sealLastTimestamp.map { min(link.timestamp - $0, 1.0 / 20) * 1000 } ?? 0
        sealLastTimestamp = link.timestamp
        stepSeal(byMs: delta)
    }

    private func stopSealLink() {
        sealLink?.invalidate()
        sealLink = nil
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            stopSealLink()
            stopPlateLink()
        } else {
            startSealLinkIfNeeded()
        }
        if sealMode {
            cometStroke = nil
            updateComet()
        }
    }

    /// A star: a bright core, a warm glow and eight rays, as the design's star sprite.
    private static func starImage(color: UIColor, glow: UIColor) -> UIImage {
        let side: CGFloat = 64
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { context in
            let cg = context.cgContext
            let center = CGPoint(x: side / 2, y: side / 2)
            let colors = [UIColor.white, color, glow.withAlphaComponent(0.45), glow.withAlphaComponent(0)].map(\.cgColor)
            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 0.08, 0.24, 0.6]
            ) {
                cg.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: side / 2, options: [])
            }
            cg.setBlendMode(.screen)
            for index in 0 ..< 8 {
                let length = index.isMultiple(of: 2) ? side / 2 : side / 4
                let width: CGFloat = index.isMultiple(of: 2) ? 1.6 : 1.1
                cg.saveGState()
                cg.translateBy(x: center.x, y: center.y)
                cg.rotate(by: CGFloat(index) * .pi / 4)
                let ray = UIBezierPath()
                ray.move(to: CGPoint(x: 0, y: -width))
                ray.addLine(to: CGPoint(x: length, y: 0))
                ray.addLine(to: CGPoint(x: 0, y: width))
                ray.close()
                color.withAlphaComponent(0.85).setFill()
                ray.fill()
                cg.restoreGState()
            }
        }
    }

    /// The comet's head: white at the heart, the in-flight cyan, fading to nothing.
    private static func cometImage(color: UIColor) -> UIImage {
        let side: CGFloat = 48
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { context in
            let center = CGPoint(x: side / 2, y: side / 2)
            let colors = [UIColor.white, color, color.withAlphaComponent(0)].map(\.cgColor)
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 0.35, 1]) {
                context.cgContext.drawRadialGradient(
                    gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: side / 2, options: []
                )
            }
        }
    }
}

/// A display link target that does not keep its owner alive.
final class FWWeakLinkTarget: NSObject {
    private let action: (CADisplayLink) -> Void

    init(_ action: @escaping (CADisplayLink) -> Void) {
        self.action = action
    }

    @objc func tick(_ link: CADisplayLink) {
        action(link)
    }
}
