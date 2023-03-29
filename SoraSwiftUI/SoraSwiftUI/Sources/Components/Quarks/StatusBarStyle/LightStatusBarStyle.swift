import UIKit

struct LightStatusBarStyle: StatusBarStyleValues {
	func value(for style: StatusBarStyle) -> UIStatusBarStyle {
		switch style {
		case .default, .alwaysDark:
			if #available(iOS 13.0, *) {
				return .darkContent
			} else {
				return .default
			}
		case .contrast, .alwaysLight:
			return .lightContent
		}
	}
}
