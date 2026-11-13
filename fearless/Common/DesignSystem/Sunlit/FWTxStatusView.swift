import UIKit

/// A transaction's state as a small ring (spec section 4): pending breathes amber while it is pending,
/// success fills and draws its checkmark, failure shakes. Only a live change (pending to settled) animates;
/// a settled transaction shows at rest. Reduced motion keeps the colours and drops the movement.
final class FWTxStatusView: UIView {
    enum Status: Equatable {
        case pending, success, failed
    }

    private(set) var status: Status?
    private let ring = CAShapeLayer()
    private let disc = CAShapeLayer()
    private let mark = CAShapeLayer()
    private let effects: FWEffects
    private var observation: NSObjectProtocol?

    init(effects: FWEffects = .shared) {
        self.effects = effects
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        for shape in [disc, ring, mark] {
            shape.fillColor = nil
            shape.lineCap = .round
            shape.lineJoin = .round
            layer.addSublayer(shape)
        }
        ring.lineWidth = 2
        mark.lineWidth = 2
        observation = effects.notificationCenter.addObserver(
            forName: FWEffects.didChange, object: effects, queue: .main
        ) { [weak self] _ in self?.refreshMotion() }
    }

    deinit {
        if let observation { effects.notificationCenter.removeObserver(observation) }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        refreshMotion()
    }

    private func refreshMotion() {
        guard let status else { return }
        setStatus(status, animated: false)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let side = min(bounds.width, bounds.height)
        let box = CGRect(x: bounds.midX - side / 2, y: bounds.midY - side / 2, width: side, height: side)
        for shape in [disc, ring, mark] {
            shape.frame = bounds
        }
        let circle = UIBezierPath(
            arcCenter: CGPoint(x: box.midX, y: box.midY), radius: side / 2 - ring.lineWidth / 2,
            startAngle: -.pi / 2, endAngle: 1.5 * .pi, clockwise: true
        )
        ring.path = circle.cgPath
        disc.path = UIBezierPath(ovalIn: box.insetBy(dx: 1, dy: 1)).cgPath
        mark.path = markPath(in: box).cgPath
        CATransaction.commit()
    }

    private func markPath(in box: CGRect) -> UIBezierPath {
        let path = UIBezierPath()
        let unit = box.width
        switch status {
        case .success:
            path.move(to: CGPoint(x: box.minX + unit * 0.28, y: box.minY + unit * 0.52))
            path.addLine(to: CGPoint(x: box.minX + unit * 0.44, y: box.minY + unit * 0.68))
            path.addLine(to: CGPoint(x: box.minX + unit * 0.73, y: box.minY + unit * 0.36))
        case .failed:
            path.move(to: CGPoint(x: box.minX + unit * 0.34, y: box.minY + unit * 0.34))
            path.addLine(to: CGPoint(x: box.minX + unit * 0.66, y: box.minY + unit * 0.66))
            path.move(to: CGPoint(x: box.minX + unit * 0.66, y: box.minY + unit * 0.34))
            path.addLine(to: CGPoint(x: box.minX + unit * 0.34, y: box.minY + unit * 0.66))
        case .pending, .none:
            break
        }
        return path
    }

    /// Shows `status`. `animated` marks a live change seen on screen; settled rows pass false.
    func setStatus(_ newStatus: Status, animated: Bool) {
        let previous = status
        status = newStatus
        layer.removeAllAnimations()
        [ring, mark, disc].forEach { $0.removeAllAnimations() }
        let color: UIColor
        switch newStatus {
        case .pending: color = FWSunlit.Palette.warning
        case .success: color = FWSunlit.Palette.success
        case .failed: color = FWSunlit.Palette.danger
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        ring.strokeColor = color.cgColor
        mark.strokeColor = color.cgColor
        disc.fillColor = newStatus == .pending ? nil : color.withAlphaComponent(0.16).cgColor
        ring.opacity = 1
        CATransaction.commit()
        setNeedsLayout()
        layoutIfNeeded()
        let policy = FWMotionPolicy.current(effects: effects)
        let live = animated && previous == .pending && newStatus != .pending && window != nil
        switch newStatus {
        case .pending:
            breathe(policy.style(for: .txPending))
        case .success where live:
            draw(policy.style(for: .txSuccess))
        case .failed where live:
            shake(policy.style(for: .txFailed))
        case .success, .failed:
            break
        }
    }

    private func breathe(_ style: FWMotionStyle) {
        guard window != nil, case let .full(duration) = style else { return }
        let breath = CABasicAnimation(keyPath: "opacity")
        breath.fromValue = 1
        breath.toValue = 0.5
        breath.duration = duration / 2
        breath.autoreverses = true
        breath.repeatCount = .infinity
        breath.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        breath.isRemovedOnCompletion = false
        ring.add(breath, forKey: "fw.breath")
    }

    private func draw(_ style: FWMotionStyle) {
        guard style.animates else { return }
        if case let .full(duration) = style {
            for (shape, delay) in [(ring, 0.0), (mark, duration * 0.4)] {
                let stroke = CABasicAnimation(keyPath: "strokeEnd")
                stroke.fromValue = 0
                stroke.toValue = 1
                stroke.duration = duration * 0.6
                stroke.beginTime = CACurrentMediaTime() + delay
                stroke.fillMode = .backwards
                stroke.timingFunction = CAMediaTimingFunction(name: .easeOut)
                shape.add(stroke, forKey: "fw.draw")
            }
        } else {
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 0
            fade.toValue = 1
            fade.duration = style.duration
            layer.add(fade, forKey: "fw.fade")
        }
    }

    private func shake(_ style: FWMotionStyle) {
        guard case let .full(duration) = style else { return }
        let distance = FWSunlit.Motion.shakeDistance
        let shake = CAKeyframeAnimation(keyPath: "transform.translation.x")
        shake.values = [0, -distance, distance, -distance, distance, 0]
        shake.keyTimes = [0, 0.15, 0.4, 0.6, 0.85, 1]
        shake.duration = duration
        layer.add(shake, forKey: "fw.shake")
    }
}
