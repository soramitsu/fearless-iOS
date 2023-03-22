import UIKit

public final class ScreenSizeMapper {

	private enum ScreenSize {
		case p320

		case p375x667

		case p414x736

		case p375x812

		case p414x896
	}

	private static let screenSize: ScreenSize = {
		let size = UIScreen.main.bounds.size
		switch (size.width, size.height) {
		case (320, _): // 5, 5c , 5s, SE(2016)
			return .p320
		case (375, 667): // 6, 6s, 7, 8, SE(2020)
			return .p375x667
		case (414, 736): // 6+, 6s+, 7+, 8+
			return .p414x736
		case (375, 812): // X, XS, 11 Pro
			return .p375x812
		case (414, 896): // XR, 11, XS Max, 11 Pro Max
			return .p414x896
		default:
			return .p414x896
		}
	}()

	public static func value<T>(small: T, medium: T, large: T) -> T {
		switch screenSize {
		case .p320:
			return small
		case .p375x667, .p375x812:
			return medium
		case .p414x736, .p414x896:
			return large
		}
	}

	public static func value<T>(small: T, other: T) -> T {
		return value(small: small, medium: other, large: other)
	}

	public static func value<T>(past: T, future: T) -> T {
		switch screenSize {
		case .p320, .p375x667, .p414x736:
			return past
		case .p375x812, .p414x896:
			return future
		}
	}

	public static func value<T>(iPhone5: T,
								iPhone6: T,
								iPhone6Plus: T,
								iPhoneX: T,
								iPhoneXR: T) -> T {
		switch screenSize {
		case .p320:
			return iPhone5
		case .p375x667:
			return iPhone6
		case .p414x736:
			return iPhone6Plus
		case .p375x812:
			return iPhoneX
		case .p414x896:
			return iPhoneXR
		}
	}
}
