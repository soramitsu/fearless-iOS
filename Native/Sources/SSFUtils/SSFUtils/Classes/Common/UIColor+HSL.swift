import UIKit

public extension UIColor {
    // MARK: - Public method

    /**
     Creates UIColor object based on given HSL values.

     - parameter hue: CGFloat with the hue value. Hue value must be between 0 and 360.
     - parameter saturation: CGFloat with the saturation value. Saturation value must be between 0 and 1.
     - parameter lightness: CGFloat with the lightness value. Lightness value must be between 0 and 1.

     - returns: A UIColor from the given HSL values.
     */

    class func colorWithHSL(hue: CGFloat, saturation: CGFloat, lightness: CGFloat) -> UIColor {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0

        let h = max(min(hue, 360.0), 0.0)
        let s = max(min(saturation, 1.0), 0.0)
        let l = max(min(lightness, 1.0), 0.0)

        let c: CGFloat = (1 - abs((2.0 * l) - 1)) * s
        let h60: CGFloat = h / 60.0
        let x: CGFloat = c * CGFloat(1 - abs(h60.truncatingRemainder(dividingBy: 2.0) - 1))

        if h < 60.0 {
            r = c
            g = x
        } else if h < 120.0 {
            r = x
            g = c
        } else if h < 180.0 {
            g = c
            b = x
        } else if h < 240.0 {
            g = x
            b = c
        } else if h < 300.0 {
            r = x
            b = c
        } else if h < 360.0 {
            r = c
            b = x
        }

        let m: CGFloat = lightness - (c / 2.0)

        r += m
        g += m
        b += m

        return UIColor(red: r, green: g, blue: b, alpha: 1.0)
    }
}
