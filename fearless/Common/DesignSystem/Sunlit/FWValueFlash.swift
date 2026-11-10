import UIKit

/// A value that changed in place flashes `up` or `down`, then fades back (spec section 4, "Price change on a
/// row", 600 ms). Reduced motion keeps the tint and shortens the fade. Never used on Calm surfaces.
enum FWValueFlash {
    static func flash(
        _ label: UILabel, direction: FWDigitRoll.Direction, settledColor: UIColor?, effects: FWEffects = .shared
    ) {
        guard direction != .none, label.window != nil else { return }
        let style = FWMotionPolicy.current(effects: effects).style(for: .priceChange)
        guard style.animates else { return }
        let text = label.text
        label.textColor = direction == .rising ? FWSunlit.Palette.priceUp : FWSunlit.Palette.priceDown
        let hold = style == .full(style.duration) ? style.duration * 0.25 : 0.3
        let fade = style == .full(style.duration) ? style.duration * 0.75 : style.duration
        DispatchQueue.main.asyncAfter(deadline: .now() + hold) { [weak label] in
            guard let label = label else { return }
            guard label.text == text, label.window != nil else {
                label.textColor = settledColor
                return
            }
            UIView.transition(
                with: label, duration: fade, options: [.transitionCrossDissolve, .curveEaseOut, .allowUserInteraction]
            ) {
                label.textColor = settledColor
            }
        }
    }
}
