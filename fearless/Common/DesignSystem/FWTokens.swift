// FWTokens.swift: GENERATED from config/design/fw.tokens.json; do not edit.
// sha256 18180aa767b87b8ac0bb767622e172328d95145817a1475a840905eec55b4315
// Regenerate: node scripts/design/gen-fw-tokens.mjs --ios <checkout>
import UIKit

/// Neon Glass tokens that are not colours. Colours are the generated colorsets in
/// Assets.xcassets/colors/FW, read through R.color.fw*().
enum FWTokens {
    static let sourceSHA256 = "18180aa767b87b8ac0bb767622e172328d95145817a1475a840905eec55b4315"

    struct Gradient {
        let colors: [UIColor]
        let locations: [NSNumber]
        /// CSS angle in degrees: 135 runs from the top-left corner to the bottom-right, 180 from top to bottom.
        let angle: CGFloat
    }

    enum Radius {
        static let xs: CGFloat = 8
        static let s: CGFloat = 12
        static let m: CGFloat = 16
        static let l: CGFloat = 24
    }

    enum Chamfer {
        static let lCut: CGFloat = 16
        static let lRadius: CGFloat = 12
        static let mCut: CGFloat = 10
        static let mRadius: CGFloat = 8
    }

    enum Spacing {
        static let s2: CGFloat = 2
        static let s4: CGFloat = 4
        static let s8: CGFloat = 8
        static let s12: CGFloat = 12
        static let s16: CGFloat = 16
        static let s20: CGFloat = 20
        static let s24: CGFloat = 24
        static let s32: CGFloat = 32
        static let s40: CGFloat = 40
        static let s48: CGFloat = 48
    }

    enum Duration {
        static let instant: TimeInterval = 0.09
        static let instantRelease: TimeInterval = 0.14
        static let fast: TimeInterval = 0.15
        static let base: TimeInterval = 0.22
        static let slow: TimeInterval = 0.32
        static let deliberate: TimeInterval = 0.45
    }

    enum Easing {
        static var standard: CAMediaTimingFunction { CAMediaTimingFunction(controlPoints: 0.2, 0, 0, 1) }
        static var exit: CAMediaTimingFunction { CAMediaTimingFunction(controlPoints: 0.3, 0, 1, 1) }
        static var expand: CAMediaTimingFunction { CAMediaTimingFunction(controlPoints: 0.05, 0.7, 0.1, 1) }
    }

    enum Alpha {
        static let glassSheen: CGFloat = 0.04
        static let glassElevatedSheen: CGFloat = 0.05
        static let chromeSheen: CGFloat = 0.03
        static let statusContainer: CGFloat = 0.14
        static let infoContainer: CGFloat = 0.12
    }

    enum Gradients {
        static var hairline: Gradient {
            Gradient(
                colors: [
                    UIColor(red: 1, green: 1, blue: 1, alpha: 0.22),
                    UIColor(red: 1, green: 1, blue: 1, alpha: 0.06),
                    UIColor(red: 1, green: 0, blue: 0.6039, alpha: 0.28),
                ],
                locations: [0, 0.42, 1],
                angle: 135
            )
        }

        static var accent: Gradient {
            Gradient(
                colors: [
                    UIColor(red: 1, green: 0, blue: 0.6039, alpha: 0.75),
                    UIColor(red: 0.5451, green: 0.3608, blue: 1, alpha: 0.55),
                    UIColor(red: 0.1804, green: 0.902, blue: 1, alpha: 0.65),
                ],
                locations: [0, 0.5, 1],
                angle: 135
            )
        }

        static var primaryFill: Gradient {
            Gradient(
                colors: [
                    UIColor(red: 0.8392, green: 0, blue: 0.498, alpha: 1),
                    UIColor(red: 0.6392, green: 0, blue: 0.4157, alpha: 1),
                ],
                locations: [0, 1],
                angle: 180
            )
        }
    }

    static let colorsets = [
        "fwBgBase",
        "fwSurfaceRaised",
        "fwSurfaceRaised2",
        "fwSurfacePressed",
        "fwSurfaceSunken",
        "fwSurfaceGlass",
        "fwSurfaceGlassElevated",
        "fwSurfaceChrome",
        "fwSurfaceChromeSolid",
        "fwScrim",
        "fwTextPrimary",
        "fwTextSecondary",
        "fwTextTertiary",
        "fwTextDisabled",
        "fwTextOnAccent",
        "fwTextLink",
        "fwTextBrand",
        "fwTextPromo",
        "fwBrand",
        "fwFillTop",
        "fwFillBottom",
        "fwAccentEdge",
        "fwFocus",
        "fwPriceUp",
        "fwPriceDown",
        "fwSuccess",
        "fwWarning",
        "fwDanger",
        "fwInfo",
        "fwDangerFill",
        "fwSelectFill",
        "fwSelectEdge",
        "fwRowSelected",
        "fwDivider",
        "fwStrokeStrong",
        "fwStrokeControl",
        "fwHudTick",
        "fwHudTrace",
        "fwThumbOff",
        "fwQrModule",
        "fwQrField",
    ]
}
