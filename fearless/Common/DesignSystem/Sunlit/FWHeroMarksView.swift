import UIKit

/// The hero's composition marks (SPEC v4 part 6): gold corner brackets and the yamato divisions of the top and bottom
/// edges, and the asanoha lattice across the card at 5 % with a band of light crossing it every 9 s that shows the
/// lattice at 32 % where it passes. The lattice is drawn once; only the band's mask moves. Reduced motion and reduced
/// effects drop the band. Decorative: hidden from assistive technologies.
final class FWHeroMarksView: UIView {
    static let bracketArm: CGFloat = 10
    static let bracketInset: CGFloat = 9
    static let bracketAlpha: Float = 0.7
    static let tickAlpha: Float = 0.45
    static let tickHalfLength: CGFloat = 3
    static let latticeCell: CGFloat = 26
    static let latticeAlpha: CGFloat = 0.05
    static let bandAlpha: CGFloat = 0.32
    static let bandWidth: CGFloat = 220
    static let bandPeriod: TimeInterval = 9
    static let bandKey = "fw.marks.band"

    private let tokens: FWShikiban?
    private let effects: FWEffects
    let brackets = CAShapeLayer()
    let ticks = CAShapeLayer()
    let lattice = CAShapeLayer()
    let bandLattice = CAShapeLayer()
    let bandMask = CAGradientLayer()
    private var observation: NSObjectProtocol?
    private var drawnSize: CGSize = .zero

    init(tokens: FWShikiban? = .bundled, effects: FWEffects = .shared) {
        self.tokens = tokens
        self.effects = effects
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        accessibilityElementsHidden = true
        backgroundColor = .clear
        let rest = FWShikiban.color(tokens?.colors.rest ?? "#FFC24A")
        let core = FWShikiban.color(tokens?.colors.core ?? "#FFD58A")
        lattice.strokeColor = rest.withAlphaComponent(Self.latticeAlpha).cgColor
        bandLattice.strokeColor = core.withAlphaComponent(Self.bandAlpha).cgColor
        for layer in [lattice, bandLattice] {
            layer.fillColor = nil
            layer.lineWidth = 0.75
        }
        brackets.strokeColor = rest.cgColor
        brackets.opacity = Self.bracketAlpha
        ticks.strokeColor = rest.cgColor
        ticks.opacity = Self.tickAlpha
        for layer in [brackets, ticks] {
            layer.fillColor = nil
            layer.lineWidth = 1 / max(1, UIScreen.main.scale)
            layer.lineCap = .square
        }
        bandMask.startPoint = CGPoint(x: 0, y: 0.5)
        bandMask.endPoint = CGPoint(x: 1, y: 0.5)
        bandMask.colors = [UIColor.clear, UIColor.black, UIColor.clear].map(\.cgColor)
        bandMask.locations = [0, 0.5, 1]
        bandLattice.mask = bandMask
        layer.addSublayer(lattice)
        layer.addSublayer(bandLattice)
        layer.addSublayer(ticks)
        layer.addSublayer(brackets)
        observation = effects.notificationCenter.addObserver(
            forName: FWEffects.didChange, object: effects, queue: .main
        ) { [weak self] _ in self?.updateBand() }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let observation { effects.notificationCenter.removeObserver(observation) }
    }

    var isBandMoving: Bool {
        bandMask.animation(forKey: Self.bandKey) != nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.size != drawnSize, bounds.width > 0 else { return }
        drawnSize = bounds.size
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for layer in [brackets, ticks, lattice, bandLattice] {
            layer.frame = bounds
        }
        brackets.path = Self.bracketsPath(in: bounds).cgPath
        ticks.path = Self.ticksPath(in: bounds).cgPath
        let latticePath = tokens?.asanohaPath(in: bounds, cell: Self.latticeCell).cgPath
        lattice.path = latticePath
        bandLattice.path = latticePath
        bandMask.bounds = CGRect(x: 0, y: 0, width: Self.bandWidth, height: bounds.height)
        bandMask.position = CGPoint(x: -Self.bandWidth / 2, y: bounds.midY)
        CATransaction.commit()
        bandMask.removeAnimation(forKey: Self.bandKey)
        updateBand()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateBand()
    }

    /// A bracket in each corner: arms 10 pt, 9 pt in from the edges.
    static func bracketsPath(in bounds: CGRect) -> UIBezierPath {
        let path = UIBezierPath()
        let m = bracketInset, a = bracketArm
        let corners: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (bounds.minX + m, bounds.minY + m, 1, 1), (bounds.maxX - m, bounds.minY + m, -1, 1),
            (bounds.minX + m, bounds.maxY - m, 1, -1), (bounds.maxX - m, bounds.maxY - m, -1, -1)
        ]
        for (x, y, dx, dy) in corners {
            path.move(to: CGPoint(x: x + dx * a, y: y))
            path.addLine(to: CGPoint(x: x, y: y))
            path.addLine(to: CGPoint(x: x, y: y + dy * a))
        }
        return path
    }

    /// The yamato divisions of the width, 1 − 1/√2, 1/2 and 1/√2, on the top and bottom edges.
    static let tickFractions: [CGFloat] = [1 - 1 / 2.0.squareRoot(), 0.5, 1 / 2.0.squareRoot()]

    static func ticksPath(in bounds: CGRect) -> UIBezierPath {
        let path = UIBezierPath()
        let m = bracketInset, h = tickHalfLength
        for fraction in tickFractions {
            let x = bounds.minX + bounds.width * fraction
            path.move(to: CGPoint(x: x, y: bounds.minY + m - h))
            path.addLine(to: CGPoint(x: x, y: bounds.minY + m + h))
            path.move(to: CGPoint(x: x, y: bounds.maxY - m - h))
            path.addLine(to: CGPoint(x: x, y: bounds.maxY - m + h))
        }
        return path
    }

    private var bandAllowed: Bool {
        !FWMotionPolicy.current(effects: effects).isRestricted && !effects.paintReduced(calm: false)
    }

    private func updateBand() {
        bandLattice.isHidden = !bandAllowed
        guard bandAllowed, window != nil, bounds.width > 0 else {
            bandMask.removeAnimation(forKey: Self.bandKey)
            return
        }
        guard bandMask.animation(forKey: Self.bandKey) == nil else { return }
        let sweep = CABasicAnimation(keyPath: "position.x")
        sweep.fromValue = -Self.bandWidth / 2
        sweep.toValue = bounds.width + Self.bandWidth / 2
        sweep.duration = Self.bandPeriod
        sweep.repeatCount = .infinity
        sweep.timingFunction = CAMediaTimingFunction(name: .linear)
        bandMask.add(sweep, forKey: Self.bandKey)
    }
}
