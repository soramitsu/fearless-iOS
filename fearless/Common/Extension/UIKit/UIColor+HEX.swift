import UIKit

extension UIColor {
    // swiftlint:disable:next large_tuple
    var rgbaComponents: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        var rComponent: CGFloat = 0
        var gComponent: CGFloat = 0
        var bComponent: CGFloat = 0
        var aComponent: CGFloat = 0

        if getRed(&rComponent, green: &gComponent, blue: &bComponent, alpha: &aComponent) {
            return (rComponent, gComponent, bComponent, aComponent)
        }

        return (0, 0, 0, 0)
    }

    var hexRGB: String {
        String(
            format: "#%02X%02X%02X",
            Int(rgbaComponents.red * 255),
            Int(rgbaComponents.green * 255),
            Int(rgbaComponents.blue * 255)
        )
    }

    var hexRGBA: String {
        String(
            format: "#%02X%02X%02X%02X",
            Int(rgbaComponents.red * 255),
            Int(rgbaComponents.green * 255),
            Int(rgbaComponents.blue * 255),
            Int(rgbaComponents.alpha * 255)
        )
    }
}
