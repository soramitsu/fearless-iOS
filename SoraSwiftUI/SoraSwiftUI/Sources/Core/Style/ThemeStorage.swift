final class ThemeStorage {

	private enum Key: String {
		case theme = "SoramitsuThemeType"
	}

	private lazy var defaults = UserDefaults.standard

	/// Сохраненная тема
	var theme: SoramitsuThemeType? {
		get {
			guard let value: Int = load(for: .theme) else { return nil }
			return SoramitsuThemeType(rawValue: value)
		}
		set {
			save(value: newValue?.rawValue, for: .theme)
		}
	}

	private func save<T>(value: T?, for key: Key) {
		defaults.set(value, forKey: key.rawValue)
	}

	private func load<T>(for key: Key) -> T? {
		defaults.value(forKey: key.rawValue) as? T
	}
}
