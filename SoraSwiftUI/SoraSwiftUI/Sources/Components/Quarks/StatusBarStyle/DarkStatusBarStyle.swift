import UIKit

struct DarkStatusBarStyle: StatusBarStyleValues {
	func value(for style: StatusBarStyle) -> UIStatusBarStyle {
		switch style {
		case .default, .alwaysLight:
			return .lightContent
		case .contrast, .alwaysDark:
			if #available(iOS 13.0, *) {
				return .darkContent
			} else {
				return .default
			}
		}
	}
}
