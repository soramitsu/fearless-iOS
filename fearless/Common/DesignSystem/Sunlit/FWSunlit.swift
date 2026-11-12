import UIKit

/// "Sun-lit neumorphism" (mobile redesign spec, 2026-11-08): one world, one light.
/// A key light from the top-left, the brand badge as an emissive bounce light and a faint violet sky
/// from the bottom-right. Dark only. Colours follow the Yatagarasu brand (2026-11-10, kit tokens/colors.json):
/// ink surfaces, pink actions, the warm ember of the crest's halo. The asset-catalog colour sets that legacy
/// screens read are kept equal to them (see `FWSunlitTests`).
enum FWSunlit {
    enum Palette {
        /// Page and every neumorphic surface: neumorphism needs one base. Brand ink.
        static let background = FWSunlit.color(0x120A2E)
        /// Inset wells, input fields and pressed controls: ink darkened in the old navy ratio (as on Android).
        static let backgroundDeep = FWSunlit.color(0x0C0722)
        /// Primary actions and active navigation: brand pink.
        static let brand = FWSunlit.color(0xE6006F)
        /// A pressed primary action: the primary fill's lower pink (brand spec, kit revision 70771ec).
        static let brandPressed = FWSunlit.color(0xA8005A)
        /// Brand pink for text and active tab labels, which need 4.5:1 on ink (the design's tab bar pink).
        static let brandText = FWSunlit.color(0xFF4FA3)
        /// The primary fill under white labels: 5.2:1 at the top. Brand pink itself stays off buttons with text.
        static let gradientStart = FWSunlit.color(0xD6006A)
        static let gradientEnd = FWSunlit.color(0xA8005A)
        /// The solar motif's gold (brand spec): the core of the badge's and the crest's halo. Emissive accents only.
        static let sun = FWSunlit.color(0xFFC24A)
        /// Edge catching the bounce light.
        static let sunRim = FWSunlit.color(0xFF3D8E)
        /// Ambient sky.
        static let violet = FWSunlit.color(0x8B5CFF)
        /// Key-light shadow.
        static let shadow = FWSunlit.color(0x05060F)
        static let textPrimary = FWSunlit.color(0xFAF6FF)
        static let textSecondary = FWSunlit.color(0xCFC4E6)
        /// Large or auxiliary text only (at least 3:1 on `bg`).
        static let textTertiary = FWSunlit.color(0x7F86AA)
        static let priceUp = FWSunlit.color(0x3DF2B0)
        static let priceDown = FWSunlit.color(0xFF9F57)
        static let success = FWSunlit.color(0x3DF2B0)
        static let warning = FWSunlit.color(0xFFC452)
        static let danger = FWSunlit.color(0xFF6B5E)
        /// QR codes keep a white field for scanners.
        static let qrField = UIColor.white

        /// The tint of a price or balance change: up, down, or the secondary text colour when unchanged.
        /// Optional so that the attributed-string builders can keep their `if let` colour binding.
        static func change(_ value: Decimal) -> UIColor? {
            if value > 0 { return priceUp }
            if value < 0 { return priceDown }
            return textSecondary
        }
    }

    /// One shadow of a two-shadow pair. `blur` is the CSS blur radius of the spec; Core Animation's
    /// `shadowRadius` is half of it.
    struct Shadow: Equatable {
        let color: UIColor
        let opacity: Float
        let offset: CGSize
        let blur: CGFloat

        var layerRadius: CGFloat { blur / 2 }

        /// Raised-1 uses the same light at 60 % of the geometry: offsets and blur scale, opacity stays.
        func scaled(_ factor: CGFloat) -> Shadow {
            Shadow(
                color: color,
                opacity: opacity,
                offset: CGSize(width: offset.width * factor, height: offset.height * factor),
                blur: blur * factor
            )
        }
    }

    /// Same light, different depth.
    enum Elevation: CaseIterable {
        /// No light of its own (text, plain containers).
        case flat
        /// List rows and chips.
        case raised1
        /// Cards, round action buttons and the tab bar.
        case raised2
        /// Inputs, pressed controls and the selected tab well.
        case inset
        /// Primary call to action, the active sync ring and the sun: brand gradient plus its own glow.
        case emissive
    }

    enum Shadows {
        /// Key-light highlight, up and to the left.
        static let highlight = Shadow(color: .white, opacity: 0.07, offset: CGSize(width: -5, height: -5), blur: 12)
        /// Key-light shadow, down and to the right.
        static let key = Shadow(color: Palette.shadow, opacity: 0.7, offset: CGSize(width: 6, height: 6), blur: 16)
        /// Inset wells mirror the pair: dark inside the top-left edges, light inside the bottom-right ones.
        static let insetDark = Shadow(color: .black, opacity: 0.6, offset: CGSize(width: 5, height: 5), blur: 10)
        static let insetLight = Shadow(color: .white, opacity: 0.045, offset: CGSize(width: -4, height: -4), blur: 9)
        /// Emissive surfaces glow in their own colour with no key-light shadow underneath.
        static let emissiveGlow = Shadow(
            color: Palette.brand, opacity: 0.45, offset: CGSize(width: 0, height: 8), blur: 22
        )
        static let raised1Factor: CGFloat = 0.6

        /// The outer pair of a raised elevation, or nil for elevations without one.
        static func pair(for elevation: Elevation) -> (highlight: Shadow, key: Shadow)? {
            switch elevation {
            case .raised1: return (highlight.scaled(raised1Factor), key.scaled(raised1Factor))
            case .raised2: return (highlight, key)
            case .flat, .inset, .emissive: return nil
            }
        }
    }

    enum Rim {
        /// Edge catching the key light: white 10 % at the top, gone by 70 % of the height.
        static let keyLightAlpha: CGFloat = 0.10
        static let keyLightMidAlpha: CGFloat = 0.08
        /// The top 1 pt highlight of an emissive surface.
        static let emissiveHighlightAlpha: CGFloat = 0.35
        /// High contrast swaps every shadow for this solid stroke.
        static let highContrastAlpha: CGFloat = 0.4
        static let width: CGFloat = 1
    }

    enum Radius {
        static let card: CGFloat = 22
        static let row: CGFloat = 20
        static let button: CGFloat = 18
        static let tabBar: CGFloat = 26
        static let tabWell: CGFloat = 16
        static let chip: CGFloat = 999
    }

    enum Spacing {
        static let grid: CGFloat = 4
        static let gutter: CGFloat = 20
    }

    /// The light model. Distances are in points, measured in the screen that shows the sun.
    enum Light {
        /// Direction the highlights face: up and to the left.
        static let keyDirection = CGVector(dx: -0.6, dy: -0.8)
        /// Strongest sun rim, on a surface that touches the sun.
        static let maxSunRim: CGFloat = 0.35
        /// Rims weaker than this are not drawn.
        static let minSunRim: CGFloat = 0.02
        /// Sun bounce on the page: brand at 18 %, halving every 0.6 screen widths.
        static let bounceAlpha: CGFloat = 0.18
        static let bounceHalfDistance: CGFloat = 0.6
        /// Ambient sky from the bottom-right corner.
        static let skyAlpha: CGFloat = 0.10
        static let skyReach: CGFloat = 0.55
        /// Where the bounce sits on screens without a sun of their own: top centre, 21 % down.
        static let defaultSunPosition = CGPoint(x: 0.5, y: 0.21)

        /// Sun rim strength for a surface whose nearest top-edge point is `distance` points from the sun.
        /// It follows the page bounce: 35 % at the sun, half that every 0.6 screen widths.
        static func sunRim(distance: CGFloat, screenWidth: CGFloat) -> CGFloat {
            guard screenWidth > 0, distance.isFinite else { return 0 }
            let halvings = max(0, distance) / (bounceHalfDistance * screenWidth)
            let strength = maxSunRim * pow(2, -halvings)
            return strength < minSunRim ? 0 : strength
        }

        /// Sun rim for a surface frame, measured from the sun centre to the nearest point of its top edge.
        static func sunRim(for frame: CGRect, sunCenter: CGPoint, screenWidth: CGFloat) -> CGFloat {
            guard !frame.isNull, !frame.isEmpty else { return 0 }
            let nearestX = min(max(sunCenter.x, frame.minX), frame.maxX)
            let nearestY = sunCenter.y > frame.minY && sunCenter.y < frame.maxY ? sunCenter.y : frame.minY
            let distance = hypot(nearestX - sunCenter.x, nearestY - sunCenter.y)
            return sunRim(distance: distance, screenWidth: screenWidth)
        }

        /// Bounce alpha at `distance` points from the sun: the same halving as the rim, from 18 %.
        static func bounce(distance: CGFloat, screenWidth: CGFloat) -> CGFloat {
            guard screenWidth > 0, distance.isFinite else { return 0 }
            return bounceAlpha * pow(2, -max(0, distance) / (bounceHalfDistance * screenWidth))
        }
    }

    /// Spec section 4. Every animation carries information.
    enum Motion {
        static let pressIn: TimeInterval = 0.09
        static let pressOut: TimeInterval = 0.16
        static let pressScale: CGFloat = 0.97
        static let balanceRoll: TimeInterval = 0.45
        static let priceFlash: TimeInterval = 0.6
        static let syncTurn: TimeInterval = 1.6
        static let syncBloom: TimeInterval = 0.5
        static let syncFailure: TimeInterval = 0.25
        static let syncFailedSunAlpha: CGFloat = 0.6
        static let listRise: TimeInterval = 0.22
        static let listStagger: TimeInterval = 0.03
        /// Kit v3 design pass: rows rise 12 pt as they enter.
        static let listRiseDistance: CGFloat = 12
        static let listMaxRows = 8
        static let tabSlide: TimeInterval = 0.26
        static let pendingBreath: TimeInterval = 1.4
        static let txSuccess: TimeInterval = 0.4
        static let shake: TimeInterval = 0.3
        static let shakeDistance: CGFloat = 6
        static let shakeCount = 2
        static let pinDotFill: TimeInterval = 0.12
        static let copied: TimeInterval = 0.9
        /// Reduced motion, Calm and Reduced effects replace movement with crossfades no longer than this.
        static let maxCrossfade: TimeInterval = 0.15
    }

    /// Opaque sRGB colour from a 0xRRGGBB literal.
    static func color(_ hex: UInt32, alpha: CGFloat = 1) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }

    /// The 0xRRGGBB value of an sRGB colour, rounded to 8 bits per channel.
    static func hex(of color: UIColor) -> UInt32? {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
        func byte(_ value: CGFloat) -> UInt32 { UInt32(max(0, min(255, (value * 255).rounded()))) }
        return byte(red) << 16 | byte(green) << 8 | byte(blue)
    }

    /// WCAG 2 contrast ratio of two opaque colours.
    static func contrast(_ first: UIColor, _ second: UIColor) -> CGFloat {
        let lighter = max(luminance(first), luminance(second))
        let darker = min(luminance(first), luminance(second))
        return (lighter + 0.05) / (darker + 0.05)
    }

    static func luminance(_ color: UIColor) -> CGFloat {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        func linear(_ channel: CGFloat) -> CGFloat {
            channel <= 0.039_28 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }
}

/// Where the current screen's sun is, in window coordinates, so surfaces in other modules (list rows,
/// action buttons) can weigh their rim light by distance. Main thread only; UI state, never persisted.
final class FWSunAnchor {
    static let shared = FWSunAnchor()

    private(set) var centerInWindow: CGPoint?
    private(set) var screenWidth: CGFloat = 0

    /// Records `sunView`'s centre. Call when the sun lays out or scrolls.
    func update(sunView: UIView) {
        guard let window = sunView.window else { return }
        centerInWindow = sunView.convert(CGPoint(x: sunView.bounds.midX, y: sunView.bounds.midY), to: nil)
        screenWidth = window.bounds.width
    }

    func clear() {
        centerInWindow = nil
    }

    /// Rim strength for `view` from its distance to the sun, or `fallback` when no sun is on screen.
    func sunRim(for view: UIView, fallback: CGFloat = 0) -> CGFloat {
        guard let sun = centerInWindow, view.window != nil, screenWidth > 0 else { return fallback }
        let frame = view.convert(view.bounds, to: nil)
        return FWSunlit.Light.sunRim(for: frame, sunCenter: sun, screenWidth: screenWidth)
    }
}

/// System controls that the app does not draw itself follow the sun-lit palette.
enum FWSunlitAppearance {
    static func apply() {
        UISwitch.appearance().onTintColor = FWSunlit.Palette.brand
        UIPageControl.appearance().currentPageIndicatorTintColor = FWSunlit.Palette.brand
        UIPageControl.appearance().pageIndicatorTintColor = FWSunlit.Palette.textTertiary
        UIRefreshControl.appearance().tintColor = FWSunlit.Palette.textSecondary
    }
}
