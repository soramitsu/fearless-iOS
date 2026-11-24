import UIKit

/// A list's first appearance: rows fade in and rise 12 pt (kit v3), staggered 30 ms, at most eight rows, 220 ms each
/// (spec section 4). Rows that appear later, by scrolling or reloads, show at once. Reduced motion, Calm
/// and Reduced effects show every row at once.
final class FWListRise {
    /// Rows displayed within this time after the first one belong to the first appearance.
    static let window: TimeInterval = 0.5

    private let effects: FWEffects
    private let clock: () -> CFTimeInterval
    private var firstRowTime: CFTimeInterval?
    private(set) var animatedRows = 0
    private(set) var isFinished = false

    init(effects: FWEffects = .shared, clock: @escaping () -> CFTimeInterval = CACurrentMediaTime) {
        self.effects = effects
        self.clock = clock
    }

    /// The delay before `cell` rises, or nil when it shows at once.
    func delayForNextRow() -> TimeInterval? {
        guard !isFinished else { return nil }
        guard case .full = FWMotionPolicy.current(effects: effects).style(for: .listAppear) else {
            isFinished = true
            return nil
        }
        let now = clock()
        let first = firstRowTime ?? now
        firstRowTime = first
        guard animatedRows < FWSunlit.Motion.listMaxRows, now - first < Self.window else {
            isFinished = true
            return nil
        }
        defer { animatedRows += 1 }
        return Double(animatedRows) * FWSunlit.Motion.listStagger
    }

    func cellWillAppear(_ cell: UIView) {
        guard let delay = delayForNextRow() else { return }
        cell.alpha = 0
        cell.transform = CGAffineTransform(translationX: 0, y: FWSunlit.Motion.listRiseDistance)
        UIView.animate(
            withDuration: FWSunlit.Motion.listRise, delay: delay,
            options: [.curveEaseOut, .allowUserInteraction, .beginFromCurrentState]
        ) {
            cell.alpha = 1
            cell.transform = .identity
        }
    }
}
