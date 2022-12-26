import UIKit

// #codegen
final class LightPalette: Palette {
	func color(_ color: SoramitsuColor) -> UIColor {
		switch color {
		case let .custom(uiColor): return uiColor
		
		case .bgSurface: return Colors.white100
		case .statusSuccess: return Colors.green50
		case .statusSuccessContainer: return Colors.green5
		case .accentSecondary: return Colors.brown90
		case .statusWarning: return Colors.yellow30
		case .bgSurfaceInverted: return Colors.brown90
		case .fgSecondary: return Colors.brown50
		case .accentPrimaryContainer: return Colors.red5
		case .accentTertiary: return Colors.brown50
		case .accentPrimary: return Colors.red50
		case .additionalPolkaswap: return Colors.polkaswap50
		case .additionalPolkaswapContainer: return Colors.polkaswap5
		case .bgSurfaceVariant: return Colors.brown10
		case .statusWarningContainer: return Colors.yellow5
		case .fgPrimary: return Colors.brown90
		case .fgOutline: return Colors.brown5
		case .fgTertiary: return Colors.brown30
		case .statusErrorContainer: return Colors.red5
		case .bgPage: return Colors.brown5
		case .accentTertiaryContainer: return Colors.brown10
		case .statusError: return Colors.red60
		case .accentSecondaryContainer: return Colors.brown10
		case .fgInverted: return Colors.brown5
		default: return .black
		}
	}
}