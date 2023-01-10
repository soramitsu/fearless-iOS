import UIKit

// #codegen
final class DarkPalette: Palette {
	func color(_ color: SoramitsuColor) -> UIColor {
		switch color {
		case let .custom(uiColor): return uiColor
		
		case .accentSecondaryContainer: return Colors.grey70
		case .fgTertiary: return Colors.brown30
		case .bgSurface: return Colors.grey80
		case .accentTertiaryContainer: return Colors.grey70
		case .bgSurfaceVariant: return Colors.grey70
		case .bgPage: return Colors.grey90
		case .statusErrorContainer: return Colors.red5
		case .statusError: return Colors.red40
		case .additionalPolkaswapContainer: return Colors.polkaswap5
		case .statusSuccessContainer: return Colors.green5
		case .statusWarningContainer: return Colors.yellow5
		case .accentSecondary: return Colors.grey5
		case .statusWarning: return Colors.yellow30
		case .accentPrimaryContainer: return Colors.red5
		case .bgSurfaceInverted: return Colors.grey5
		case .fgPrimary: return Colors.grey5
		case .fgSecondary: return Colors.grey50
		case .statusSuccess: return Colors.green40
		case .additionalPolkaswap: return Colors.polkaswap40
		case .fgOutline: return Colors.brown5
		case .fgInverted: return Colors.grey90
		case .accentTertiary: return Colors.grey50
		case .accentPrimary: return Colors.red40
		default: return .black
		}
	}
}