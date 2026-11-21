import UIKit

/// The loader (SPEC v4 part 4): three comets, the crow's three legs, circling the mirror's eight-lobed rim a third of a
/// turn apart, each with a tail fading to nothing; the rim and an inner circle rest under them. With a known amount
/// the comets go and the rim fills clockwise from 12 o'clock to that share. Reduced motion: the comets stand still
/// and fade in turn. The comets are stroke windows on a three-turn rim path that Core Animation slides, so nothing
/// redraws per frame, and they run only while the view is on screen.
final class FWMirrorLoaderView: UIView {
    /// The app's own full-page or section loader.
    static let pageSide: CGFloat = 96
    /// Fee and quote estimates.
    static let inlineSide: CGFloat = 24

    private let tokens: FWShikiban?
    private let effects: FWEffects
    private let rimGlow = CAShapeLayer()
    private let rimCore = CAShapeLayer()
    private let innerGlow = CAShapeLayer()
    private let innerCore = CAShapeLayer()
    private let fillGlow = CAShapeLayer()
    private let fillCore = CAShapeLayer()
    private var comets: [CALayer] = []
    private var segments: [[(glow: CAShapeLayer, core: CAShapeLayer)]] = []
    private var observation: NSObjectProtocol?
    static let segmentCount = 8
    static let runKey = "fw.loader.run"
    static let restKey = "fw.loader.rest"

    /// A known share 0–1, or nil while the amount is unknown (the comets run).
    var progress: Double? {
        didSet {
            guard progress != oldValue else { return }
            updateProgress()
            updateMotion()
        }
    }

    init(tokens: FWShikiban? = .bundled, effects: FWEffects = .shared) {
        self.tokens = tokens
        self.effects = effects
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        backgroundColor = .clear
        let glow = FWShikiban.color(tokens?.colors.glow ?? "#FF8A42").cgColor
        let core = FWShikiban.color(tokens?.colors.core ?? "#FFD58A").cgColor
        let star = FWShikiban.color(tokens?.colors.star ?? "#FFE9BE").cgColor
        func stroke(_ color: CGColor) -> CAShapeLayer {
            let layer = CAShapeLayer()
            layer.fillColor = nil
            layer.strokeColor = color
            layer.lineCap = .round
            layer.lineJoin = .round
            return layer
        }
        let restAlpha = Float(tokens?.loader.restAlpha ?? 0.25)
        let resting: [(CAShapeLayer, CGColor, Float)] = [
            (rimGlow, glow, 0.3 * restAlpha), (rimCore, core, restAlpha),
            (innerGlow, glow, 0.3 * restAlpha * 0.8), (innerCore, core, restAlpha * 0.8),
            (fillGlow, glow, Float(0.3)), (fillCore, core, Float(1))
        ]
        for (layer, color, alpha) in resting {
            layer.strokeColor = color
            layer.fillColor = nil
            layer.lineCap = .round
            layer.lineJoin = .round
            layer.opacity = alpha
            self.layer.addSublayer(layer)
        }
        fillGlow.strokeEnd = 0
        fillCore.strokeEnd = 0
        for _ in 0 ..< (tokens?.loader.comets ?? 3) {
            let comet = CALayer()
            var pieces: [(glow: CAShapeLayer, core: CAShapeLayer)] = []
            for index in 0 ..< Self.segmentCount {
                let share = CGFloat(index) / CGFloat(Self.segmentCount)
                let glowPiece = stroke(glow)
                glowPiece.opacity = Float(0.3 * (1 - share))
                let corePiece = stroke(index < 2 ? star : core)
                corePiece.opacity = Float(1 - share)
                comet.addSublayer(glowPiece)
                comet.addSublayer(corePiece)
                pieces.append((glowPiece, corePiece))
            }
            layer.addSublayer(comet)
            comets.append(comet)
            segments.append(pieces)
        }
        observation = effects.notificationCenter.addObserver(
            forName: FWEffects.didChange, object: effects, queue: .main
        ) { [weak self] _ in self?.updateMotion() }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let observation { effects.notificationCenter.removeObserver(observation) }
    }

    var isRunning: Bool {
        comets.first?.sublayers?.first?.animation(forKey: Self.runKey) != nil
    }

    private var radius: CGFloat { min(bounds.width, bounds.height) / 2 * 0.94 }
    private var width: CGFloat { max(1.25, radius * 0.045) }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let tokens else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let rim = tokens.mirrorRimPath(center: center, radius: radius).cgPath
        let inner = UIBezierPath(
            arcCenter: center, radius: radius * CGFloat(tokens.mirror.cusp * 0.94 / tokens.ratio.yamato),
            startAngle: 0, endAngle: 2 * .pi, clockwise: true
        ).cgPath
        for layer in [rimGlow, rimCore, innerGlow, innerCore, fillGlow, fillCore] {
            layer.frame = bounds
        }
        rimGlow.path = rim
        rimCore.path = rim
        innerGlow.path = inner
        innerCore.path = inner
        rimGlow.lineWidth = width * 3
        rimCore.lineWidth = width
        innerGlow.lineWidth = width * 0.6 * 3
        innerCore.lineWidth = width * 0.6
        // The filled share starts at 12 o'clock.
        let fill = tokens.rimPath(center: center, radius: radius, from: 0, to: 1).cgPath
        fillGlow.path = fill
        fillCore.path = fill
        fillGlow.lineWidth = width * 1.4 * 5
        fillCore.lineWidth = width * 1.4
        // Comets ride a three-turn path so their windows never wrap.
        let track = tokens.rimPath(center: center, radius: radius, from: 0, to: 3).cgPath
        for (comet, pieces) in zip(comets, segments) {
            comet.frame = bounds
            for (index, piece) in pieces.enumerated() {
                let taper = 1 - CGFloat(index) / CGFloat(Self.segmentCount) * 0.5
                piece.glow.frame = bounds
                piece.core.frame = bounds
                piece.glow.path = track
                piece.core.path = track
                piece.glow.lineWidth = width * 1.4 * taper * 5
                piece.core.lineWidth = width * 1.4 * taper
            }
        }
        CATransaction.commit()
        restartMotion()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateMotion()
    }

    /// Each comet segment's window on the three-turn track at time 0: (start, end) as path fractions.
    static func window(comet: Int, segment: Int, tokens: FWShikiban) -> (start: Double, end: Double) {
        let offset = Double(comet) / Double(tokens.loader.comets)
        let head = 1 + offset - tokens.loader.tailTurn * Double(segment) / Double(segmentCount)
        let tail = 1 + offset - tokens.loader.tailTurn * Double(segment + 1) / Double(segmentCount)
        return (tail / 3, head / 3)
    }

    private func updateProgress() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let share = CGFloat(progress.map { min(1, max(0.001, $0)) } ?? 0)
        fillGlow.strokeEnd = share
        fillCore.strokeEnd = share
        comets.forEach { $0.isHidden = progress != nil }
        CATransaction.commit()
    }

    private func restartMotion() {
        for pieces in segments {
            for piece in pieces {
                piece.glow.removeAllAnimations()
                piece.core.removeAllAnimations()
            }
        }
        comets.forEach { $0.removeAnimation(forKey: Self.restKey) }
        updateMotion()
    }

    private func updateMotion() {
        guard let tokens else { return }
        let running = window != nil && progress == nil && bounds.width > 0
        let moving = !FWMotionPolicy.current(effects: effects).isRestricted
        let now = CACurrentMediaTime()
        for (cometIndex, pieces) in segments.enumerated() {
            for (index, piece) in pieces.enumerated() {
                let window = Self.window(comet: cometIndex, segment: index, tokens: tokens)
                for layer in [piece.glow, piece.core] {
                    layer.strokeStart = CGFloat(window.start)
                    layer.strokeEnd = CGFloat(window.end)
                    guard running, moving else {
                        layer.removeAnimation(forKey: Self.runKey)
                        continue
                    }
                    guard layer.animation(forKey: Self.runKey) == nil else { continue }
                    let start = CABasicAnimation(keyPath: "strokeStart")
                    start.fromValue = window.start
                    start.toValue = window.start + 1.0 / 3
                    let end = CABasicAnimation(keyPath: "strokeEnd")
                    end.fromValue = window.end
                    end.toValue = window.end + 1.0 / 3
                    let group = CAAnimationGroup()
                    group.animations = [start, end]
                    group.duration = tokens.loader.secondsPerTurn
                    group.repeatCount = .infinity
                    group.beginTime = now
                    group.timingFunction = CAMediaTimingFunction(name: .linear)
                    layer.add(group, forKey: Self.runKey)
                }
            }
            let comet = comets[cometIndex]
            if running, !moving {
                guard comet.animation(forKey: Self.restKey) == nil else { continue }
                // Standing still, the comets fade in turn, one every 720 ms.
                let step = (tokens.durationsMs.count > 6 ? tokens.durationsMs[6] : 720) / 1000
                let fade = CAKeyframeAnimation(keyPath: "opacity")
                fade.values = [0.35, 1, 0.35, 0.35]
                fade.keyTimes = [0, NSNumber(value: 1.0 / 6), NSNumber(value: 1.0 / 3), 1]
                fade.duration = step * Double(comets.count)
                fade.repeatCount = .infinity
                fade.beginTime = now + step * Double(cometIndex) - fade.duration
                comet.add(fade, forKey: Self.restKey)
            } else {
                comet.removeAnimation(forKey: Self.restKey)
            }
        }
    }
}
