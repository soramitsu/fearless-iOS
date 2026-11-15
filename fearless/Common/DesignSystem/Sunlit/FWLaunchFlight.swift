import UIKit

// MARK: - Tiers

/// A part of a first screen and its depth tier for the launch flight and later arrivals (SPEC v4 part 1).
/// Tier 0 is nearest: the first thing the eye should land on.
struct FWFlightTier {
    let view: UIView
    let tier: Int
}

/// A screen that declares how it comes apart in depth. Wallet home: 0 the balance card, 1 the round actions, 2 the
/// header and the tab bar, 3 the segment control, 4 the list. PIN, unlock, welcome: 0 the mark or title, 1 the main
/// control, 2 the rest. A screen that declares nothing flies as one piece at tier 0.
protocol FWFlightTiered: AnyObject {
    var flightTiers: [FWFlightTier] { get }
}

enum FWFlightTierFinder {
    /// The tiers of the screen `root` shows: its own, its presented screen's (which covers it), a tab container's
    /// and its selected tab's, a navigation stack's top. Falls back to the root's view as one piece.
    static func tiers(in root: UIViewController?) -> [FWFlightTier] {
        guard let root else { return [] }
        let found = collect(root).filter { $0.view.window != nil && !$0.view.isHidden }
        if found.isEmpty, let view = root.viewIfLoaded {
            return [FWFlightTier(view: view, tier: 0)]
        }
        return found
    }

    private static func collect(_ controller: UIViewController) -> [FWFlightTier] {
        if let presented = controller.presentedViewController, !presented.isBeingDismissed {
            return collect(presented)
        }
        var tiers = (controller as? FWFlightTiered)?.flightTiers ?? []
        if let tabs = controller as? UITabBarController, let selected = tabs.selectedViewController {
            tiers += collect(selected)
        } else if let navigation = controller as? UINavigationController, let top = navigation.topViewController {
            tiers += collect(top)
        }
        return tiers
    }
}

/// How each tier view is scaled about the focus point. Depth is a plain scale about a point; a tier inside another
/// tier gets the ratio of the two scales, so both read as one scale about the focus on screen.
struct FWTierPlan {
    struct Entry {
        let view: UIView
        let tier: Int
        /// The view's centre in window coordinates, before any transform.
        let center: CGPoint
        /// The nearest enclosing tier view, if any (index into `entries`).
        let parent: Int?
        let originalAlpha: CGFloat
    }

    let entries: [Entry]
    let focus: CGPoint

    init(tiers: [FWFlightTier], focus: CGPoint) {
        self.focus = focus
        var unique: [FWFlightTier] = []
        for tier in tiers where !unique.contains(where: { $0.view === tier.view }) {
            unique.append(tier)
        }
        entries = unique.map { tier in
            let view = tier.view
            let center = view.superview?.convert(view.center, to: nil) ?? view.center
            var parent: Int?
            var ancestor = view.superview
            while let current = ancestor, parent == nil {
                parent = unique.firstIndex { $0.view === current }
                ancestor = current.superview
            }
            return Entry(view: view, tier: tier.tier, center: center, parent: parent, originalAlpha: view.alpha)
        }
    }

    /// A scale `scale` about `focus` for a view centred at `center` (UIKit transforms act about the centre).
    static func transform(scale: CGFloat, about focus: CGPoint, center: CGPoint) -> CGAffineTransform {
        CGAffineTransform(
            a: scale, b: 0, c: 0, d: scale,
            tx: (1 - scale) * (focus.x - center.x), ty: (1 - scale) * (focus.y - center.y)
        )
    }

    /// The local transform for each entry, given each tier's on-screen scale.
    func transforms(scaleForTier: (Int) -> CGFloat) -> [CGAffineTransform] {
        entries.map { entry in
            let own = scaleForTier(entry.tier)
            let inherited = entry.parent.map { scaleForTier(entries[$0].tier) } ?? 1
            return Self.transform(scale: own / max(inherited, 0.0001), about: focus, center: entry.center)
        }
    }

    /// Each entry's opacity, given each tier's share; an enclosing tier's opacity already applies to its children.
    func alphas(opacityForTier: (Int) -> CGFloat) -> [CGFloat] {
        entries.map { entry in
            let own = opacityForTier(entry.tier)
            guard let parent = entry.parent else { return entry.originalAlpha * own }
            let inherited = max(opacityForTier(entries[parent].tier), 0.0001)
            return entry.originalAlpha * min(1, own / inherited)
        }
    }

    func apply(scaleForTier: (Int) -> CGFloat, opacityForTier: (Int) -> CGFloat) {
        let transforms = transforms(scaleForTier: scaleForTier)
        let alphas = alphas(opacityForTier: opacityForTier)
        for (index, entry) in entries.enumerated() {
            entry.view.transform = transforms[index]
            entry.view.alpha = alphas[index]
        }
    }

    /// Every tier at rest: identity transforms and the views' own opacity. Nothing is left on a view after a flight.
    func restore() {
        for entry in entries {
            entry.view.transform = .identity
            entry.view.alpha = entry.originalAlpha
        }
    }
}

// MARK: - The launch flight

/// The launch flight (SPEC v4 part 1): six gates about the dive's focus over the clip, the mirror opening through the
/// overlay with the corona round it, and the first screen's tiers flying up through the opening. One display link
/// drives it while it runs; it animates transforms, opacity and paths only (no layout).
final class FWLaunchFlight: NSObject {
    private let tokens: FWShikiban
    private weak var cover: UIView?
    private let plan: FWTierPlan
    private let focusInCover: CGPoint
    private let feedback: FWFeedbackPlaying
    private let onCleared: () -> Void
    private let onFinished: () -> Void

    private let flightLayer = CALayer()
    private let corona = CALayer()
    private let coronaGradient = CAGradientLayer()
    private let gatesLayer = CALayer()
    private var gateLayers: [GateLayers] = []
    private let mask = CAShapeLayer()

    private var link: CADisplayLink?
    private var lastTimestamp: CFTimeInterval?
    private(set) var elapsedMs: Double = 0
    private(set) var rate: Double = 1
    private var arrived = false
    private var cleared = false
    private(set) var isFinished = false

    private struct GateLayers {
        let glow: CAShapeLayer
        let core: CAShapeLayer
        let innerGlow: CAShapeLayer
        let innerCore: CAShapeLayer
        let corners: CAShapeLayer
    }

    init(
        tokens: FWShikiban,
        cover: UIView,
        tiers: [FWFlightTier],
        focus: CGPoint,
        feedback: FWFeedbackPlaying,
        onCleared: @escaping () -> Void,
        onFinished: @escaping () -> Void
    ) {
        self.tokens = tokens
        self.cover = cover
        plan = FWTierPlan(tiers: tiers, focus: focus)
        focusInCover = cover.convert(focus, from: nil)
        self.feedback = feedback
        self.onCleared = onCleared
        self.onFinished = onFinished
        super.init()
        buildLayers(in: cover)
    }

    private func buildLayers(in cover: UIView) {
        let colors = tokens.colors
        flightLayer.frame = cover.bounds
        corona.frame = cover.bounds
        corona.backgroundColor = FWShikiban.color(tokens.flight.corona.last?.color ?? colors.rest).cgColor
        corona.opacity = 0
        coronaGradient.type = .radial
        coronaGradient.startPoint = CGPoint(x: 0.5, y: 0.5)
        coronaGradient.endPoint = CGPoint(x: 1, y: 1)
        coronaGradient.colors = tokens.flight.corona.map { FWShikiban.color($0.color).cgColor }
        corona.addSublayer(coronaGradient)
        flightLayer.addSublayer(corona)
        gatesLayer.frame = cover.bounds
        flightLayer.addSublayer(gatesLayer)
        let glow = FWShikiban.color(colors.glow).cgColor
        let core = FWShikiban.color(colors.core).cgColor
        let star = FWShikiban.color(colors.star).cgColor
        // Far gates first, so a near gate's glow lies over them.
        for _ in tokens.gates {
            func stroke(_ color: CGColor, screen: Bool) -> CAShapeLayer {
                let layer = CAShapeLayer()
                layer.fillColor = nil
                layer.strokeColor = color
                layer.lineCap = .round
                layer.lineJoin = .round
                if screen { layer.compositingFilter = "screenBlendMode" }
                return layer
            }
            let corners = CAShapeLayer()
            corners.fillColor = star
            corners.strokeColor = nil
            corners.compositingFilter = "screenBlendMode"
            let layers = GateLayers(
                glow: stroke(glow, screen: true),
                core: stroke(core, screen: false),
                innerGlow: stroke(glow, screen: true),
                innerCore: stroke(core, screen: false),
                corners: corners
            )
            gateLayers.append(layers)
        }
        for layers in gateLayers.reversed() {
            for layer in [layers.glow, layers.innerGlow, layers.core, layers.innerCore, layers.corners] {
                layer.frame = cover.bounds
                layer.isHidden = true
                gatesLayer.addSublayer(layer)
            }
        }
        cover.layer.addSublayer(flightLayer)
        mask.fillRule = .evenOdd
        mask.fillColor = UIColor.black.cgColor
        mask.frame = cover.bounds
    }

    /// Starts the flight now. The screen underneath is already in place; its tiers start far off and unseen.
    func start() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        render()
        CATransaction.commit()
        let link = CADisplayLink(target: self, selector: #selector(step(_:)))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    /// A tap plays the rest of the flight 2.5 times faster.
    func skip() {
        rate = tokens.skipRate
    }

    @objc private func step(_ link: CADisplayLink) {
        let now = link.timestamp
        // A long main-thread stall must not jump the flight past whole phases.
        let delta = lastTimestamp.map { min(now - $0, 1.0 / 20) * 1000 } ?? 0
        lastTimestamp = now
        advance(byMs: delta)
    }

    /// Moves the flight on by `ms` of wall time (at the current rate) and draws it.
    func advance(byMs ms: Double) {
        guard !isFinished else { return }
        elapsedMs += ms * rate
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        render()
        CATransaction.commit()
    }

    private func render() {
        let ms = elapsedMs
        let duration = tokens.flight.durationMs
        if ms >= duration {
            finish()
            return
        }
        if !arrived, ms >= 1000 {
            arrived = true
            feedback.play(.launchArrive)
        }
        let u = FWShikiban.clamp01(ms / duration)
        plan.apply(
            scaleForTier: { CGFloat(tokens.tierScale($0, u)) },
            opacityForTier: { CGFloat(tokens.tierOpacity($0, atMs: ms)) }
        )
        guard !cleared, let cover else { return }
        let bounds = cover.bounds
        let side = Double(min(bounds.width, bounds.height))
        drawGates(u: u, side: side)
        let radius = CGFloat(tokens.irisRadius(atMs: ms, side: side))
        if radius > 0 {
            let path = UIBezierPath(rect: bounds)
            path.append(UIBezierPath(
                arcCenter: focusInCover, radius: radius, startAngle: 0, endAngle: 2 * .pi, clockwise: true
            ))
            mask.path = path.cgPath
            if cover.layer.mask !== mask { cover.layer.mask = mask }
            drawCorona(radius: radius, side: CGFloat(side), ms: ms)
            if radius >= Self.farthestCorner(from: focusInCover, in: bounds) {
                cleared = true
                onCleared()
            }
        }
    }

    private func drawGates(u: Double, side: Double) {
        let fade = FWShikiban.clamp01(u / tokens.flight.gateFadeIn)
        for (index, gate) in tokens.gates.enumerated() {
            let layers = gateLayers[index]
            let scale = tokens.gateScale(index, u)
            let alpha = tokens.gateAlpha(index, u) * fade
            let all = [layers.glow, layers.core, layers.innerGlow, layers.innerCore, layers.corners]
            guard scale > 0, alpha > 0 else {
                all.forEach { $0.isHidden = true }
                continue
            }
            all.forEach { $0.isHidden = false }
            let radius = CGFloat(tokens.flight.baseRadius * side * scale)
            let width = CGFloat(FWShikiban.gateWidth(scale: scale))
            if gate.isMirror {
                let rim = tokens.mirrorRimPath(center: focusInCover, radius: radius).cgPath
                let inner = UIBezierPath(
                    arcCenter: focusInCover, radius: radius * CGFloat(tokens.mirror.cusp * 0.94),
                    startAngle: 0, endAngle: 2 * .pi, clockwise: true
                ).cgPath
                Self.style(glow: layers.glow, core: layers.core, path: rim, width: width * 1.25, alpha: alpha)
                Self.style(glow: layers.innerGlow, core: layers.innerCore, path: inner, width: width * 0.7, alpha: alpha * 0.8)
                layers.corners.isHidden = true
                continue
            }
            let circle = UIBezierPath(
                arcCenter: focusInCover, radius: radius, startAngle: 0, endAngle: 2 * .pi, clockwise: true
            ).cgPath
            let square = UIBezierPath()
            let dots = UIBezierPath()
            for (corner, point) in (gate.square ?? []).enumerated() where point.count == 2 {
                let position = CGPoint(x: focusInCover.x + CGFloat(point[0]) * radius, y: focusInCover.y + CGFloat(point[1]) * radius)
                if corner == 0 { square.move(to: position) } else { square.addLine(to: position) }
                let dot = width * 1.5
                dots.append(UIBezierPath(ovalIn: CGRect(x: position.x - dot, y: position.y - dot, width: dot * 2, height: dot * 2)))
            }
            square.close()
            Self.style(glow: layers.glow, core: layers.core, path: circle, width: width, alpha: alpha)
            Self.style(glow: layers.innerGlow, core: layers.innerCore, path: square.cgPath, width: width * 0.75, alpha: alpha * 0.85)
            layers.corners.path = dots.cgPath
            layers.corners.opacity = Float(alpha)
        }
    }

    /// The figures' stroke: a soft glow five times as wide under the bright core.
    private static func style(glow: CAShapeLayer, core: CAShapeLayer, path: CGPath, width: CGFloat, alpha: Double) {
        glow.path = path
        glow.lineWidth = width * 5
        glow.opacity = Float(0.3 * alpha)
        core.path = path
        core.lineWidth = width
        core.opacity = Float(alpha)
    }

    private func drawCorona(radius: CGFloat, side: CGFloat, ms: Double) {
        let strength = FWShikiban.clamp01((ms - tokens.flight.irisAtMs) / tokens.flight.coronaMs)
        corona.opacity = Float(strength)
        let outer = max(radius * 2.4, radius + side * 0.5)
        coronaGradient.frame = CGRect(x: focusInCover.x - outer, y: focusInCover.y - outer, width: outer * 2, height: outer * 2)
        coronaGradient.locations = tokens.flight.corona.map {
            NSNumber(value: Double((radius + CGFloat($0.offset) * (outer - radius)) / outer))
        }
    }

    static func farthestCorner(from point: CGPoint, in bounds: CGRect) -> CGFloat {
        let dx = max(point.x - bounds.minX, bounds.maxX - point.x)
        let dy = max(point.y - bounds.minY, bounds.maxY - point.y)
        return (dx * dx + dy * dy).squareRoot()
    }

    /// Ends the flight at once: every tier at rest, the display link gone.
    func finish() {
        guard !isFinished else { return }
        isFinished = true
        link?.invalidate()
        link = nil
        plan.restore()
        if !arrived {
            arrived = true
            feedback.play(.launchArrive)
        }
        flightLayer.removeFromSuperlayer()
        if !cleared {
            cleared = true
            onCleared()
        }
        onFinished()
    }

    /// Stops without the arrival touch (the app went to the background, or the overlay gave up).
    func cancel() {
        guard !isFinished else { return }
        isFinished = true
        link?.invalidate()
        link = nil
        plan.restore()
        flightLayer.removeFromSuperlayer()
    }
}

// MARK: - Later arrivals

/// A later arrival (an unlock): no gates. Tier `k` goes from `flight.landingFrom[k]` to 1 about the focus with
/// `easing.settle` over `landingMs`, starting `k × tierStaggerMs` later, fading in over the first 45 %. Core Animation
/// runs it from keyframes; the views' own values never change, so nothing is left on them.
enum FWLanding {
    static let fadeShare = 0.45
    static let animationKey = "fw.landing.tier"

    /// The scale and opacity of tier `tier` at `ms` into the landing.
    static func state(tier: Int, atMs ms: Double, tokens: FWShikiban) -> (scale: Double, opacity: Double) {
        let local = FWShikiban.clamp01((ms - Double(tier) * tokens.flight.tierStaggerMs) / tokens.flight.landingMs)
        return (tokens.landingScale(tier, tokens.settle(local)), FWShikiban.clamp01(local / fadeShare))
    }

    static func totalMs(maxTier: Int, tokens: FWShikiban) -> Double {
        tokens.flight.landingMs + Double(maxTier) * tokens.flight.tierStaggerMs
    }

    static func animate(tiers: [FWFlightTier], focus: CGPoint, tokens: FWShikiban) {
        let plan = FWTierPlan(tiers: tiers, focus: focus)
        guard !plan.entries.isEmpty else { return }
        let maxTier = plan.entries.map(\.tier).max() ?? 0
        let total = totalMs(maxTier: maxTier, tokens: tokens)
        let samples = 60
        var transforms: [[NSValue]] = Array(repeating: [], count: plan.entries.count)
        var alphas: [[NSNumber]] = Array(repeating: [], count: plan.entries.count)
        for sample in 0 ... samples {
            let ms = total * Double(sample) / Double(samples)
            let scales = plan.transforms { CGFloat(state(tier: $0, atMs: ms, tokens: tokens).scale) }
            let opacity = plan.alphas { CGFloat(state(tier: $0, atMs: ms, tokens: tokens).opacity) }
            for index in plan.entries.indices {
                transforms[index].append(NSValue(caTransform3D: CATransform3DMakeAffineTransform(scales[index])))
                alphas[index].append(NSNumber(value: Double(opacity[index])))
            }
        }
        for (index, entry) in plan.entries.enumerated() {
            let move = CAKeyframeAnimation(keyPath: "transform")
            move.values = transforms[index]
            let fade = CAKeyframeAnimation(keyPath: "opacity")
            fade.values = alphas[index]
            let group = CAAnimationGroup()
            group.animations = [move, fade]
            group.duration = total / 1000
            group.timingFunction = CAMediaTimingFunction(name: .linear)
            entry.view.layer.add(group, forKey: animationKey)
        }
    }
}
