import Foundation

extension TriangularedView {
    func applyDisabledStyle() {
        fillColor = R.color.colorDarkGray()!
        strokeColor = .clear
    }

    func applyEnabledStyle() {
        fillColor = .clear
        strokeColor = R.color.colorGray()!
    }
}
