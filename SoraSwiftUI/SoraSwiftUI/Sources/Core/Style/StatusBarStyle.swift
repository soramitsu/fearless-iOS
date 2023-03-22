import UIKit

public enum StatusBarStyle: CaseIterable {
	case contrast
	case `default`
	case alwaysLight
	case alwaysDark
}

protocol StatusBarStyleValues {
	func value(for style: StatusBarStyle) -> UIStatusBarStyle
}
