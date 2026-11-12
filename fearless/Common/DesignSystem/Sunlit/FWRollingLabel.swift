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
    private var countLink: CADisplayLink?
    private var countRun: FWCountUp.Run?
    private var countStart: CFTimeInterval = 0
    private var countDuration: TimeInterval = FWCountUp.duration
    private var pendingCountUp: String?

    /// True while the value counts up to its final text.
    var isCounting: Bool { countRun != nil }

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
        if window == nil {
            finishChange()
        } else if let pending = pendingCountUp {
            pendingCountUp = nil
            countUp(to: pending)
        }
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

    // MARK: - Count up

    /// Counts from zero to `newText` over `duration` (kit v3 "living balance": the total's first reveal after
    /// launch). VoiceOver and copying always read the final value. Reduced motion and Calm show it at once; a text
    /// whose number cannot be reproduced exactly is shown at once too.
    func countUp(to newText: String, duration: TimeInterval = FWCountUp.duration) {
        finishChange()
        guard let run = FWCountUp.Run(final: newText),
              case .full = FWMotionPolicy.current(effects: effects, calm: calm).style(for: .balanceChange) else {
            text = newText
            return
        }
        guard window != nil else {
            text = newText
            pendingCountUp = newText
            return
        }
        countRun = run
        countStart = CACurrentMediaTime()
        countDuration = duration
        accessibilityLabel = newText
        text = run.text(progress: 0)
        let link = CADisplayLink(target: FWCountUpTarget(label: self), selector: #selector(FWCountUpTarget.tick))
        link.add(to: .main, forMode: .common)
        countLink = link
    }

    fileprivate func countTick() {
        guard let run = countRun else { return }
        let progress = min(1, (CACurrentMediaTime() - countStart) / max(0.01, countDuration))
        text = run.text(progress: progress)
        if progress >= 1 { stopCount() }
    }

    private func stopCount() {
        countLink?.invalidate()
        countLink = nil
        if let run = countRun {
            text = run.final
            accessibilityLabel = nil
        }
        countRun = nil
    }

    private func finishChange() {
        stopCount()
        pendingCountUp = nil
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

/// Breaks the display link's strong reference to the label.
private final class FWCountUpTarget: NSObject {
    weak var label: FWRollingLabel?

    init(label: FWRollingLabel) {
        self.label = label
        super.init()
    }

    @objc func tick() {
        label?.countTick()
    }
}

/// The count of a formatted amount from zero to its value, keeping its affixes, marks and fraction digits.
enum FWCountUp {
    static let duration: TimeInterval = 0.6

    struct Run: Equatable {
        let final: String
        let prefix: String
        let suffix: String
        let value: Decimal
        let fractionDigits: Int
        let decimalMark: Character?
        let groupMark: Character?

        /// Nil when the text has no number, or its number cannot be written back exactly.
        init?(final: String) {
            let characters = Array(final)
            guard let first = characters.firstIndex(where: \.isWholeNumber),
                  let last = characters.lastIndex(where: \.isWholeNumber) else { return nil }
            let core = Array(characters[first ... last])
            let marks = core.filter { !$0.isWholeNumber }
            let points = marks.filter { $0 == "." || $0 == "," }
            var decimal: Character?
            if Set(points).count > 1 {
                decimal = points.last
            } else if let mark = points.first, points.count == 1, let index = core.firstIndex(of: mark) {
                decimal = core.distance(from: index, to: core.endIndex) - 1 == 3 && marks.count == 1 ? nil : mark
            }
            let integerPart = decimal.flatMap { mark in core.lastIndex(of: mark).map { Array(core[..<$0]) } } ?? core
            let fractionPart = decimal.flatMap { mark in core.lastIndex(of: mark).map { Array(core[($0 + 1)...]) } } ?? []
            let groups = Set(integerPart.filter { !$0.isWholeNumber })
            guard groups.count <= 1, fractionPart.allSatisfy(\.isWholeNumber) else { return nil }
            let integerDigits = String(integerPart.filter(\.isWholeNumber))
            let fractionDigits = String(fractionPart)
            guard let value = Decimal(
                string: integerDigits + (fractionDigits.isEmpty ? "" : "." + fractionDigits),
                locale: Locale(identifier: "en_US_POSIX")
            ) else { return nil }
            self.final = final
            prefix = String(characters[..<first])
            suffix = String(characters[(last + 1)...])
            self.value = value
            self.fractionDigits = fractionDigits.count
            decimalMark = decimal
            groupMark = groups.first
            guard text(at: value) == final else { return nil }
        }

        /// The text at `progress` of the count (0–1), easing out.
        func text(progress: Double) -> String {
            let clamped = min(1, max(0, progress))
            guard clamped < 1 else { return final }
            let eased = 1 - pow(1 - clamped, 3)
            return text(at: value * Decimal(eased))
        }

        /// `amount` written as the final text writes its number.
        func text(at amount: Decimal) -> String {
            var scaled = amount * pow(Decimal(10), fractionDigits)
            var rounded = Decimal()
            NSDecimalRound(&rounded, &scaled, 0, .down)
            var digits = NSDecimalNumber(decimal: max(0, rounded)).stringValue
            if digits.count <= fractionDigits {
                digits = String(repeating: "0", count: fractionDigits - digits.count + 1) + digits
            }
            let integer = String(digits.dropLast(fractionDigits))
            let fraction = String(digits.suffix(fractionDigits))
            var grouped = integer
            if let groupMark {
                grouped = ""
                for (index, character) in integer.enumerated() {
                    if index > 0, (integer.count - index) % 3 == 0 { grouped.append(groupMark) }
                    grouped.append(character)
                }
            }
            let number = fractionDigits > 0 ? grouped + String(decimalMark ?? ".") + fraction : grouped
            return prefix + number + suffix
        }
    }
}
