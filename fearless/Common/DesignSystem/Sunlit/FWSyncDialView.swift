import UIKit

/// What the wallet home knows about its networks for the sync dial (SPEC v4 part 2). Only real answers count.
enum FWDialModel: Equatable {
    /// Per-network answers: `done` answered, `failed` gave up, out of `total`.
    case counts(done: Int, failed: Int, total: Int)
    /// Busy with nothing countable: the comet over an unlit ring.
    case busy
    /// Idle with nothing countable: the settled dial.
    case settled

    /// From the wallet home's sync tracker: the networks it connects, those connected and those given up.
    static func from(tracker: FWSyncTracker) -> FWDialModel {
        let total = tracker.connections.count
        guard total > 0 else {
            return tracker.isSyncing ? .busy : .settled
        }
        let done = tracker.connections.values.filter { $0 == .connected }.count
        return .counts(done: done, failed: tracker.unreachable, total: total)
    }

    var state: FWDialState {
        switch self {
        case let .counts(done, failed, total):
            return FWShikiban.dialState(done: done, failed: failed, total: total)
        case .busy:
            return FWShikiban.dialState(done: 0, failed: 0, total: 0)
        case .settled:
            return FWDialState(phase: .live, lit: 0 ... 1, failed: 1 ... 1, done: 0, total: 0)
        }
    }

    /// The count shown in place of the status words while syncing, "9 / 14"; nil otherwise.
    var countText: String? {
        guard case let .counts(done, _, total) = self, state.phase == .syncing else { return nil }
        return "\(done) / \(total)"
    }
}

/// The sync dial: a ring of eight segments, gold up to the share that answered, ember for the share that gave up, a
/// cyan comet circling while anything is outstanding; settled, a gold centre and one thin ring that expands and fades.
/// The comet is a Core Animation rotation, so nothing redraws per frame; it runs only while on screen and syncing.
/// Reduced motion shows the lit share without the comet or the ring.
final class FWSyncDialView: UIView {
    static let side: CGFloat = 18

    private let tokens: FWShikiban?
    private let effects: FWEffects
    private let restLayer = CAShapeLayer()
    private let litLayer = CAShapeLayer()
    private let failedLayer = CAShapeLayer()
    private let cometLayer = CALayer()
    private var cometPieces: [CAShapeLayer] = []
    private let dotLayer = CAShapeLayer()
    private let sealRing = CAShapeLayer()
    private var observation: NSObjectProtocol?
    private(set) var model: FWDialModel = .busy

    static let cometKey = "fw.dial.comet"
    static let sealKey = "fw.dial.seal"

    init(tokens: FWShikiban? = .bundled, effects: FWEffects = .shared) {
        self.tokens = tokens
        self.effects = effects
        super.init(frame: CGRect(x: 0, y: 0, width: Self.side, height: Self.side))
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        backgroundColor = .clear
        let colors = tokens?.colors
        let rest = FWShikiban.color(colors?.rest ?? "#FFC24A")
        restLayer.strokeColor = rest.withAlphaComponent(0.2).cgColor
        failedLayer.strokeColor = FWShikiban.color(colors?.failure ?? "#FF5A4D").cgColor
        for layer in [restLayer, litLayer, failedLayer, sealRing] {
            layer.fillColor = nil
            layer.lineCap = .butt
            self.layer.addSublayer(layer)
        }
        let flight = FWShikiban.color(colors?.flight ?? "#38E8E0")
        for index in 0 ..< 10 {
            let piece = CAShapeLayer()
            piece.fillColor = nil
            piece.lineCap = .butt
            piece.strokeColor = flight.withAlphaComponent(0.9 * (1 - CGFloat(index) / 10)).cgColor
            cometLayer.addSublayer(piece)
            cometPieces.append(piece)
        }
        layer.addSublayer(cometLayer)
        dotLayer.fillColor = rest.cgColor
        layer.addSublayer(dotLayer)
        sealRing.strokeColor = FWShikiban.color(colors?.core ?? "#FFD58A").cgColor
        sealRing.opacity = 0
        observation = effects.notificationCenter.addObserver(
            forName: FWEffects.didChange, object: effects, queue: .main
        ) { [weak self] _ in self?.updateMotion() }
        apply(animated: false)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let observation { effects.notificationCenter.removeObserver(observation) }
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: Self.side, height: Self.side)
    }

    var radius: CGFloat { min(bounds.width, bounds.height) * 0.36 }
    private var lineWidth: CGFloat { max(1.5, radius * 0.2) }
    private var ringCenter: CGPoint { CGPoint(x: bounds.midX, y: bounds.midY) }

    var isMotionAllowed: Bool {
        !FWMotionPolicy.current(effects: effects).isRestricted
    }

    /// Whether the comet is running (on screen, outstanding work, motion allowed).
    var isCometRunning: Bool {
        cometLayer.animation(forKey: Self.cometKey) != nil
    }

    func set(_ model: FWDialModel, animated: Bool) {
        guard model != self.model else { return }
        let wasSettled = self.model.state.phase.isSettled
        self.model = model
        apply(animated: animated && !wasSettled && model.state.phase.isSettled)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for layer in [restLayer, litLayer, failedLayer, sealRing, dotLayer] {
            layer.frame = bounds
        }
        cometLayer.frame = bounds
        for piece in cometPieces {
            piece.frame = cometLayer.bounds
        }
        drawStatic()
        CATransaction.commit()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateMotion()
    }

    private func arcPath(_ ranges: [ClosedRange<Double>], radius: CGFloat? = nil) -> CGPath {
        let path = UIBezierPath()
        let r = radius ?? self.radius
        for range in ranges {
            path.append(UIBezierPath(
                arcCenter: ringCenter, radius: r,
                startAngle: CGFloat(-Double.pi / 2 + range.lowerBound * 2 * .pi),
                endAngle: CGFloat(-Double.pi / 2 + range.upperBound * 2 * .pi),
                clockwise: true
            ))
        }
        return path.cgPath
    }

    private func drawStatic() {
        guard let tokens else { return }
        let state = model.state
        let segments = 0 ..< tokens.dial.segments
        let width = lineWidth
        restLayer.lineWidth = width
        litLayer.lineWidth = width
        failedLayer.lineWidth = width
        restLayer.path = arcPath(segments.compactMap { tokens.dialSegment($0, 0 ... 1) })
        litLayer.path = arcPath(segments.compactMap { tokens.dialSegment($0, state.lit) })
        let core = FWShikiban.color(tokens.colors.core), rest = FWShikiban.color(tokens.colors.rest)
        litLayer.strokeColor = (state.phase == .syncing ? core : rest).cgColor
        failedLayer.path = arcPath(segments.compactMap { tokens.dialSegment($0, state.failed) })
        for (index, piece) in cometPieces.enumerated() {
            let a = -tokens.dial.cometTurn * Double(index) / 10
            let b = -tokens.dial.cometTurn * Double(index + 1) / 10
            piece.path = arcPath([b ... a])
            piece.lineWidth = width
        }
        let dot = radius * 0.36
        dotLayer.path = UIBezierPath(ovalIn: CGRect(x: ringCenter.x - dot, y: ringCenter.y - dot, width: dot * 2, height: dot * 2)).cgPath
        dotLayer.isHidden = !state.phase.isSettled
        sealRing.path = arcPath([0 ... 1])
        sealRing.lineWidth = max(1, width * 0.35)
    }

    private func apply(animated sealing: Bool) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        drawStatic()
        CATransaction.commit()
        updateMotion()
        if sealing, isMotionAllowed, window != nil, let tokens {
            let grow = CABasicAnimation(keyPath: "transform.scale")
            grow.fromValue = 1
            grow.toValue = 2.1
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 0.9
            fade.toValue = 0
            let group = CAAnimationGroup()
            group.animations = [grow, fade]
            group.duration = tokens.dial.sealMs / 1000
            group.timingFunction = FWShikiban.timing(tokens.easing.settle)
            sealRing.add(group, forKey: Self.sealKey)
        }
    }

    private func updateMotion() {
        let outstanding = !model.state.phase.isSettled
        cometLayer.isHidden = !outstanding || !isMotionAllowed
        guard outstanding, isMotionAllowed, window != nil, let tokens else {
            cometLayer.removeAnimation(forKey: Self.cometKey)
            return
        }
        guard cometLayer.animation(forKey: Self.cometKey) == nil else { return }
        let spin = CABasicAnimation(keyPath: "transform.rotation.z")
        spin.fromValue = 0
        spin.toValue = 2 * Double.pi
        spin.duration = tokens.dial.cometSeconds
        spin.repeatCount = .infinity
        cometLayer.add(spin, forKey: Self.cometKey)
    }
}

/// The dial and, while syncing, the count beside it in cyan tabular figures. The accessible label is the app's
/// existing connection words with the two numbers.
final class FWSyncDialRow: UIView {
    let dial: FWSyncDialView
    let countLabel = UILabel()
    private let stack = UIStackView()
    var locale: Locale = .current {
        didSet { updateAccessibility() }
    }

    init(tokens: FWShikiban? = .bundled, effects: FWEffects = .shared) {
        dial = FWSyncDialView(tokens: tokens, effects: effects)
        super.init(frame: .zero)
        countLabel.textColor = FWShikiban.color(tokens?.colors.flight ?? "#38E8E0")
        countLabel.font = UIFontMetrics(forTextStyle: .caption1).scaledFont(
            for: .monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        )
        countLabel.adjustsFontForContentSizeCategory = true
        countLabel.isHidden = true
        countLabel.isAccessibilityElement = false
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 6
        // The count sits to the dial's left, so the dial keeps its place when the count goes.
        stack.addArrangedSubview(countLabel)
        stack.addArrangedSubview(dial)
        addSubview(stack)
        // Right-aligned: the dial keeps its place and the count grows to its left.
        stack.snp.makeConstraints { make in
            make.top.bottom.trailing.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview()
        }
        dial.snp.makeConstraints { make in
            make.size.equalTo(FWSyncDialView.side)
        }
        isAccessibilityElement = true
        accessibilityTraits = [.staticText, .updatesFrequently]
        updateAccessibility()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func set(_ model: FWDialModel, animated: Bool) {
        dial.set(model, animated: animated)
        let text = model.countText
        countLabel.text = text
        countLabel.isHidden = text == nil
        updateAccessibility()
    }

    private func updateAccessibility() {
        let languages = locale.rLanguages
        let state = dial.model.state
        if state.phase.isSettled {
            accessibilityLabel = R.string.localizable.networkStatusConnected(preferredLanguages: languages)
        } else {
            let words = R.string.localizable.networkStatusConnecting(preferredLanguages: languages)
            accessibilityLabel = dial.model.countText.map { "\(words) \($0)" } ?? words
        }
    }
}
