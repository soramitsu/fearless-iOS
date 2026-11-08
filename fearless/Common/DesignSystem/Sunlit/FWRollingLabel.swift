import UIKit

/// A label whose changed digits roll to a new value, with the changed part tinted up or down before the
/// tint fades (spec section 4, "Balance changes"). Reduced motion and Calm swap the roll for a short
/// crossfade that keeps the tint. Layout, Dynamic Type and VoiceOver always read the label's own text.
final class FWRollingLabel: UILabel {
    /// Colour the text settles to after a tinted change.
    var settledColor: UIColor? {
        didSet { if !isAnimatingChange { textColor = settledColor } }
    }

    var calm = false { didSet { if calm { finishChange() } } }
    var upColor = FWSunlit.Palette.priceUp
    var downColor = FWSunlit.Palette.priceDown

    private let effects: FWEffects
    private var observation: NSObjectProtocol?
    private var overlay: UIView?
    private var changeID = 0
    private var hidesOwnText = false
    private(set) var isAnimatingChange = false

    init(effects: FWEffects = .shared) {
        self.effects = effects
        super.init(frame: .zero)
        observation = effects.notificationCenter.addObserver(
            forName: FWEffects.didChange, object: effects, queue: .main
        ) { [weak self] _ in self?.finishChange() }
    }

    deinit {
        if let observation { effects.notificationCenter.removeObserver(observation) }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { finishChange() }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func drawText(in rect: CGRect) {
        guard !hidesOwnText else { return }
        super.drawText(in: rect)
    }

    /// Shows `newText`; animates only a change between two non-empty values on screen.
    func setText(_ newText: String?, animated: Bool) {
        let oldText = text
        guard newText != oldText else { return }
        finishChange()
        guard animated, window != nil, let old = oldText, let new = newText, !old.isEmpty, !new.isEmpty else {
            text = newText
            return
        }
        let plan = FWDigitRoll.plan(from: old, to: new)
        let motion = FWMotionPolicy.current(effects: effects, calm: calm).style(for: .balanceChange)
        let tint: UIColor? = plan.direction == .rising ? upColor : (plan.direction == .falling ? downColor : nil)
        text = new
        guard let changed = plan.changed, motion.animates, plan.direction != .none,
              FWDigitRoll.isSameFormat(old, new) else { return }
        superview?.layoutIfNeeded()
        if case .full = motion, let geometry = singleLineGeometry(for: new) {
            roll(plan, changed: changed, tint: tint, geometry: geometry, duration: motion.duration)
        } else {
            crossfade(changed: changed, tint: tint, duration: motion.duration)
        }
    }

    // MARK: - Roll

    private struct Geometry {
        let origin: CGPoint
        let widths: [CGFloat]
        let height: CGFloat
    }

    private func singleLineGeometry(for value: String) -> Geometry? {
        guard let font = font, bounds.width > 0 else { return nil }
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let widths = value.map { String($0).size(withAttributes: attributes).width }
        let total = widths.reduce(0, +)
        let height = ceil(font.lineHeight)
        guard total <= bounds.width, bounds.height < height * 2 else { return nil }
        let originX: CGFloat
        switch effectiveAlignment {
        case .center: originX = (bounds.width - total) / 2
        case .right: originX = bounds.width - total
        default: originX = 0
        }
        return Geometry(origin: CGPoint(x: originX, y: (bounds.height - height) / 2), widths: widths, height: height)
    }

    private var effectiveAlignment: NSTextAlignment {
        guard textAlignment == .natural else { return textAlignment }
        return effectiveUserInterfaceLayoutDirection == .rightToLeft ? .right : .left
    }

    private func roll(
        _ plan: FWDigitRoll.Plan, changed: Range<Int>, tint: UIColor?, geometry: Geometry, duration: TimeInterval
    ) {
        changeID += 1
        let id = changeID
        let (container, moves) = makeOverlay(plan, changed: changed, tint: tint, geometry: geometry)
        addSubview(container)
        overlay = container
        hidesOwnText = true
        isAnimatingChange = true
        setNeedsDisplay()
        UIView.animate(withDuration: duration, delay: 0, options: [.curveEaseOut, .allowUserInteraction]) {
            for (view, transform) in moves {
                view.transform = transform
                view.alpha = transform == .identity ? 1 : 0
            }
        } completion: { [weak self] _ in
            guard let self = self, self.changeID == id else { return }
            // The label's own text sits exactly under the overlay: fading the overlay fades the tint.
            self.hidesOwnText = false
            self.setNeedsDisplay()
            UIView.animate(withDuration: duration, delay: 0.2, options: [.curveEaseOut, .allowUserInteraction]) {
                container.alpha = 0
            } completion: { [weak self] _ in
                guard let self = self, self.changeID == id else { return }
                self.finishChange()
            }
        }
    }

    /// One clipped cell per character of the new text; rolling digits travel through their cell.
    private func makeOverlay(
        _ plan: FWDigitRoll.Plan, changed: Range<Int>, tint: UIColor?, geometry: Geometry
    ) -> (UIView, [(UILabel, CGAffineTransform)]) {
        let container = UIView(frame: bounds)
        container.isUserInteractionEnabled = false
        container.isAccessibilityElement = false
        var cursor = geometry.origin.x
        var moves: [(UILabel, CGAffineTransform)] = []
        let travel = geometry.height * (plan.direction == .falling ? -1 : 1)
        for (index, slot) in plan.slots.enumerated() {
            let width = geometry.widths[index]
            let cell = UIView(frame: CGRect(x: cursor, y: geometry.origin.y, width: width, height: geometry.height))
            cell.clipsToBounds = true
            cursor += width
            container.addSubview(cell)
            let color = changed.contains(index) ? (tint ?? textColor) : textColor
            switch slot {
            case let .stay(character):
                cell.addSubview(glyph(character, in: cell.bounds, color: textColor))
            case let .roll(from, target):
                let leaving = glyph(from, in: cell.bounds, color: textColor)
                let arriving = glyph(target, in: cell.bounds, color: color)
                arriving.transform = CGAffineTransform(translationX: 0, y: travel)
                cell.addSubview(leaving)
                cell.addSubview(arriving)
                moves.append((leaving, CGAffineTransform(translationX: 0, y: -travel)))
                moves.append((arriving, .identity))
            case let .fade(character):
                let arriving = glyph(character, in: cell.bounds, color: color)
                arriving.alpha = 0
                cell.addSubview(arriving)
                moves.append((arriving, .identity))
            }
        }
        return (container, moves)
    }

    private func glyph(_ character: Character, in frame: CGRect, color: UIColor?) -> UILabel {
        let label = UILabel(frame: frame)
        label.text = String(character)
        label.font = font
        label.textColor = color
        label.textAlignment = .center
        label.isAccessibilityElement = false
        return label
    }

    // MARK: - Crossfade

    private func crossfade(changed: Range<Int>, tint: UIColor?, duration: TimeInterval) {
        guard let tint = tint, let value = text else { return }
        changeID += 1
        let id = changeID
        isAnimatingChange = true
        let tinted = NSMutableAttributedString(
            string: value, attributes: [.font: font as Any, .foregroundColor: textColor as Any]
        )
        let range = NSRange(location: changed.lowerBound, length: changed.count)
        if NSMaxRange(range) <= (value as NSString).length {
            tinted.addAttribute(.foregroundColor, value: tint, range: range)
        }
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = textAlignment
        paragraph.lineBreakMode = lineBreakMode
        tinted.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: tinted.length))
        UIView.transition(with: self, duration: duration, options: .transitionCrossDissolve) {
            self.attributedText = tinted
        } completion: { [weak self] _ in
            guard let self = self, self.changeID == id else { return }
            UIView.transition(
                with: self, duration: duration, options: [.transitionCrossDissolve, .curveEaseOut]
            ) {
                self.text = value
            } completion: { [weak self] _ in
                guard let self = self, self.changeID == id else { return }
                self.isAnimatingChange = false
            }
        }
    }

    private func finishChange() {
        changeID += 1
        layer.removeAllAnimations()
        overlay?.removeFromSuperview()
        overlay = nil
        if hidesOwnText {
            hidesOwnText = false
            setNeedsDisplay()
        }
        if isAnimatingChange, let value = text, attributedText?.string == value {
            text = value
        }
        isAnimatingChange = false
        if let settledColor = settledColor {
            textColor = settledColor
        }
    }
}
