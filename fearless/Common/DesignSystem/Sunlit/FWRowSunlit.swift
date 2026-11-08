import SnapKit
import UIKit

/// Sun-lit extras a list row shares: an inset well behind its icon, and an up or down flash when the row
/// shows a new value for the same item (spec section 4, "Price change on a row").
final class FWRowSunlit {
    /// Rim for rows before the screen's sun has been measured: about where a list starts under the hero.
    static let fallbackRim = FWSunlit.Light.sunRim(distance: 320, screenWidth: 390)

    let iconWell: FWNeuView = {
        let view = FWNeuView()
        view.style = .inset
        view.isUserInteractionEnabled = false
        view.shape = { UIBezierPath(ovalIn: $0) }
        return view
    }()

    private var key: String?
    private var value: String?

    /// A Raised-1 rounded surface for a row.
    static func rowSurface() -> FWNeuView {
        let view = FWNeuView()
        view.style = .raised1
        view.isUserInteractionEnabled = false
        view.shape = { UIBezierPath(roundedRect: $0, cornerRadius: FWSunlit.Radius.row) }
        return view
    }

    /// A Raised-1 rounded row background built on the app's shared surface view.
    static func rowBackground() -> TriangularedView {
        let view = TriangularedView()
        view.fillColor = FWSunlit.Palette.background
        view.highlightedFillColor = FWSunlit.Palette.backgroundDeep
        view.shadowOpacity = 0
        view.fwElevation = .raised1
        view.fwCornerRadius = FWSunlit.Radius.row
        return view
    }

    /// Sets the well into `container`, centred under `icon` and `growth` points larger.
    func installWell(behind icon: UIView, in container: UIView, growth: CGFloat) {
        container.insertSubview(iconWell, belowSubview: icon)
        iconWell.snp.makeConstraints { make in
            make.center.equalTo(icon)
            make.size.equalTo(icon).offset(growth)
        }
    }

    /// Flashes `label` when the row shows a different `value` for the same `key`.
    func show(value newValue: String?, for newKey: String, flashing label: UILabel, settledColor: UIColor?) {
        defer {
            key = newKey
            value = newValue
        }
        guard key == newKey, let old = value, let new = newValue, old != new else { return }
        let direction = FWDigitRoll.direction(from: Array(old), to: Array(new))
        FWValueFlash.flash(label, direction: direction, settledColor: settledColor)
    }
}
