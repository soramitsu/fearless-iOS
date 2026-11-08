import UIKit

/// A static 1 pt highlight inside the sheet's top edge. The sheet's existing presentation supplies
/// its motion; the rim adds none, including in recovery and signing flows without a shared marker.
enum FWSheetRim {
    private static let name = "fw.sheetRim"

    static func attach(to sheet: UIView) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        let rim = (sheet.layer.sublayers?.first { $0.name == name } as? CAGradientLayer) ?? CAGradientLayer()
        rim.name = name
        rim.startPoint = CGPoint(x: 0, y: 0.5)
        rim.endPoint = CGPoint(x: 1, y: 0.5)
        let light = UIColor(white: 1, alpha: FWSunlit.Rim.keyLightAlpha * 1.4)
        rim.colors = [UIColor(white: 1, alpha: 0), light, UIColor(white: 1, alpha: 0.04)].map(\.cgColor)
        rim.locations = [0, 0.3, 1]
        let inset = max(sheet.layer.cornerRadius, 16)
        rim.frame = CGRect(x: inset, y: 0.5, width: max(0, sheet.bounds.width - inset * 2), height: 1)
        if rim.superlayer == nil {
            sheet.layer.addSublayer(rim)
        }
        rim.removeAllAnimations()
        rim.opacity = 1
    }

    /// Keeps the rim on the sheet's top edge after the sheet resizes.
    static func layout(in sheet: UIView) {
        guard let rim = sheet.layer.sublayers?.first(where: { $0.name == name }) else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let inset = max(sheet.layer.cornerRadius, 16)
        rim.frame = CGRect(x: inset, y: 0.5, width: max(0, sheet.bounds.width - inset * 2), height: 1)
        CATransaction.commit()
    }
}
