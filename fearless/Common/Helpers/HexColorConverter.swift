import UIKit

final class HexColorConverter {
    static func uiColorToHexRGB(color: UIColor) -> String {
        color.hexRGB
    }

    static func uiColorToHexRGBA(color: UIColor) -> String {
        color.hexRGBA
    }

    static func hexStringToUIColor(hex: String?) -> UIColor? {
        guard let hex = hex else {
            return nil
        }
        var cString: String = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        if cString.hasPrefix("#") {
            cString.remove(at: cString.startIndex)
        }

        if cString.count != 6 {
            return nil
        }

        var rgbValue: UInt64 = 0
        Scanner(string: cString).scanHexInt64(&rgbValue)

        return UIColor(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: CGFloat(1.0)
        )
    }
}
