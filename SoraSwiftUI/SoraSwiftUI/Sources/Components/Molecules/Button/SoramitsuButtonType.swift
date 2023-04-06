import Foundation
import UIKit

public enum SoramitsuButtonType {
    case filled(SoramitsuButtonStyle)
    case bleached(SoramitsuButtonStyle)
    case tonal(SoramitsuButtonStyle)
    case outlined(SoramitsuButtonStyle)
    case text(SoramitsuButtonStyle)

    var enabledBackgroundColor: SoramitsuColor {
        switch self {
        case .filled(let style):
            switch style {
            case .primary: return .accentPrimary
            case .secondary: return .accentSecondary
            case .tertiary: return .accentTertiary
            }

        case .bleached: return .bgSurface

        case .tonal(let style):
            switch style {
            case .primary: return .accentPrimaryContainer
            case .secondary: return .accentSecondaryContainer
            case .tertiary: return .accentTertiaryContainer
            }

        case .outlined: return .custom(uiColor: .clear)
        case .text: return .custom(uiColor: .clear)
        }
    }

    var disabledBackgroundColor: SoramitsuColor {
        switch self {
        case .filled, .bleached, .tonal:
            return .fgPrimary

        case .outlined, .text:
            return .custom(uiColor: .clear)
        }
    }

    var disabledTintColor: SoramitsuColor {
        return .fgPrimary
    }

    var disabledBorderColor: SoramitsuColor? {
        guard case .outlined = self else {
          return nil
        }

        return .fgPrimary
    }

    var pressedSublayerColor: SoramitsuColor {
        switch self {
        case .filled: return .custom(uiColor: .white)

        case .bleached(let style):
            switch style {
            case .primary:
                return .accentPrimary
            case .secondary:
                return .accentSecondary
            case .tertiary:
                return .accentTertiary
            }

        case .tonal(let style):
            switch style {
            case .primary:
                return .accentPrimary
            case .secondary:
                return .accentSecondary
            case .tertiary:
                return .accentTertiary
            }

        case .outlined(let style):
            switch style {
            case .primary:
                return .accentPrimary
            case .secondary:
                return .accentSecondary
            case .tertiary:
                return .accentTertiary
            }

        case .text(let style):
            switch style {
            case .primary:
                return .accentPrimary
            case .secondary:
                return .accentSecondary
            case .tertiary:
                return .accentTertiary
            }
        }
    }

    var tintColor: SoramitsuColor {
        switch self {
        case .filled: return .custom(uiColor: .white)

        case .bleached(let style):
            switch style {
            case .primary:
                return .accentPrimary
            case .secondary:
                return .accentSecondary
            case .tertiary:
                return .accentTertiary
            }

        case .tonal(let style):
            switch style {
            case .primary:
                return .accentPrimary
            case .secondary:
                return .accentSecondary
            case .tertiary:
                return .accentTertiary
            }

        case .outlined(let style):
            switch style {
            case .primary:
                return .accentPrimary
            case .secondary:
                return .accentSecondary
            case .tertiary:
                return .accentTertiary
            }

        case .text(let style):
            switch style {
            case .primary:
                return .accentPrimary
            case .secondary:
                return .accentSecondary
            case .tertiary:
                return .accentTertiary
            }
        }
    }
}
