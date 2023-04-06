public enum SoramitsuThemeType: Int {
	case light
	case dark

    public var palette: Palette {
		switch self {
		case .light: return LightPalette()
		case .dark: return DarkPalette()
		}
	}

	var statusBar: StatusBarStyleValues {
		switch self {
		case .light: return LightStatusBarStyle()
		case .dark: return DarkStatusBarStyle()
		}
	}
}

public enum SoramitsuThemeMode {
	case system
	case manual(SoramitsuThemeType)
}


extension SoramitsuThemeMode: Equatable {
    public static func == (lhs: SoramitsuThemeMode, rhs: SoramitsuThemeMode) -> Bool {
            switch (lhs, rhs) {
            case (.system, .system):
                return true
            case (.manual(let lmode), .manual(let rmode)):
                return lmode == rmode
            default:
                return false
            }
        }
}
