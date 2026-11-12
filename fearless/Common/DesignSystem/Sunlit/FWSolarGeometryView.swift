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
    private let content = CALayer()
    private let tickLayer = CAShapeLayer()
    private var strokeLayers: [(stroke: FWSolarGeometry.Stroke, core: CAShapeLayer, glow: CAShapeLayer)] = []
    private var starLayers: [(star: FWSolarGeometry.Star, layer: CALayer)] = []
    private(set) var isIgnited = false
    private var turning = false

    init(geometry: FWSolarGeometry? = .bundled, effects: FWEffects = .shared) {
        self.geometry = geometry
        self.effects = effects
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
            let opacity = groupOpacity[stroke.group] ?? 1
            core.path = path
            glow.path = path
            core.lineWidth = max(0.6, CGFloat(geometry.stroke.core * stroke.weight) * radius * 2)
            glow.lineWidth = max(2, CGFloat(geometry.stroke.glow * stroke.weight) * radius)
            core.opacity = opacity
            glow.opacity = opacity
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
        tickLayer.opacity = groupOpacity["ticks"] ?? groupOpacity["ring"] ?? 1
        for (star, layer) in starLayers {
            let side = CGFloat(star.size) * radius
            layer.bounds = CGRect(x: 0, y: 0, width: side, height: side)
            layer.position = CGPoint(x: center.x + CGFloat(star.x) * radius, y: center.y + CGFloat(star.y) * radius)
            layer.opacity = groupOpacity["stars"] ?? 1
        }
        CATransaction.commit()
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
}
