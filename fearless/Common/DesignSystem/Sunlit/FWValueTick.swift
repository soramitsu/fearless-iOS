import UIKit

/// The value tick (SPEC v4 part 5): when a value the user is looking at on the wallet home changes after its first
/// display, the new text comes in 6 pt from below if it grew (from above if it shrank) over 180 ms, and a one-point
/// line under it in the price-up or price-down colour sweeps left to right and fades over 510 ms. At most once per
/// row in 3 s. Reduced motion: no tick. The label's text (and so its accessible value) is already the new one.
enum FWValueTick {
    static let travel: CGFloat = 6
    static let slideMs: Double = 180
    static let lineMs: Double = 510
    static let quietPeriod: TimeInterval = 3
    static let slideKey = "fw.tick.slide"
    static let lineName = "fw.tick.line"

    private static var lastTick: [String: TimeInterval] = [:]

    /// Whether row `key` may tick now (at most once in 3 s); records the tick when it may.
    static func claim(key: String, now: TimeInterval = ProcessInfo.processInfo.systemUptime) -> Bool {
        if let last = lastTick[key], now - last < quietPeriod { return false }
        lastTick[key] = now
        return true
    }

    static func resetForTesting() {
        lastTick = [:]
    }

    static func allowed(effects: FWEffects) -> Bool {
        !FWMotionPolicy.current(effects: effects).isRestricted
    }

    /// A row's value changed: the slide and the line, once per row in 3 s.
    @discardableResult
    static func tick(
        _ label: UILabel, direction: FWDigitRoll.Direction, key: String, effects: FWEffects = .shared
    ) -> Bool {
        guard direction != .none, label.window != nil, allowed(effects: effects), claim(key: key) else { return false }
        slide(label, direction: direction)
        // The row may set the new text right after reporting it: measure the line once it has.
        DispatchQueue.main.async { [weak label] in
            guard let label else { return }
            line(under: label, direction: direction, effects: effects)
        }
        return true
    }

    /// The new text comes in from 6 pt below (grew) or above (shrank).
    static func slide(_ label: UILabel, direction: FWDigitRoll.Direction) {
        let move = CABasicAnimation(keyPath: "transform.translation.y")
        move.fromValue = direction == .rising ? travel : -travel
        move.toValue = 0
        let appear = CABasicAnimation(keyPath: "opacity")
        appear.fromValue = 0
        appear.toValue = label.layer.opacity
        let group = CAAnimationGroup()
        group.animations = [move, appear]
        group.duration = slideMs / 1000
        group.timingFunction = settleTiming
        label.layer.add(group, forKey: slideKey)
    }

    /// A one-point line under the label sweeps left to right and fades (the total gains this alone).
    @discardableResult
    static func line(under label: UILabel, direction: FWDigitRoll.Direction, effects: FWEffects = .shared) -> CALayer? {
        guard direction != .none, label.window != nil, allowed(effects: effects) else { return nil }
        label.layer.sublayers?.filter { $0.name == lineName }.forEach { $0.removeFromSuperlayer() }
        let textWidth = min(label.bounds.width, label.intrinsicContentSize.width)
        let x: CGFloat
        switch label.effectiveTextAlignment {
        case .center: x = (label.bounds.width - textWidth) / 2
        case .right: x = label.bounds.width - textWidth
        default: x = 0
        }
        let line = CALayer()
        line.name = lineName
        line.backgroundColor = (direction == .rising ? FWSunlit.Palette.priceUp : FWSunlit.Palette.priceDown).cgColor
        line.anchorPoint = CGPoint(x: 0, y: 0.5)
        line.bounds = CGRect(x: 0, y: 0, width: textWidth, height: 1)
        line.position = CGPoint(x: x, y: label.bounds.maxY + 1)
        line.opacity = 0
        label.layer.addSublayer(line)
        let sweep = CAKeyframeAnimation(keyPath: "transform.scale.x")
        sweep.values = [0.001, 1, 1]
        sweep.keyTimes = [0, 0.5, 1]
        let fade = CAKeyframeAnimation(keyPath: "opacity")
        fade.values = [1, 1, 0]
        fade.keyTimes = [0, 0.5, 1]
        let group = CAAnimationGroup()
        group.animations = [sweep, fade]
        group.duration = lineMs / 1000
        CATransaction.begin()
        CATransaction.setCompletionBlock { line.removeFromSuperlayer() }
        line.add(group, forKey: "fw.tick.sweep")
        CATransaction.commit()
        return line
    }

    private static var settleTiming: CAMediaTimingFunction {
        FWShikiban.bundled.map { FWShikiban.timing($0.easing.settle) } ?? CAMediaTimingFunction(name: .easeOut)
    }
}

private extension UILabel {
    var effectiveTextAlignment: NSTextAlignment {
        switch textAlignment {
        case .natural:
            return effectiveUserInterfaceLayoutDirection == .rightToLeft ? .right : .left
        default:
            return textAlignment
        }
    }
}
