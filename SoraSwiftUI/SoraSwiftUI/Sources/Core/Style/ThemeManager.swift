import UIKit

final class ThemeManager {

	var theme: SoramitsuThemeType {
        switch mode {
        case .system:
            return systemTheme
        case let .manual(theme):
            return theme
        }
    }

	var themeMode: SoramitsuThemeMode {
		get {
			return mode
		}
		set {
			self.mode = newValue
			switch mode {
			case .system:
				storage.theme = nil
			case let .manual(theme):
				storage.theme = theme
			}
			updateTheme()
		}
	}

	private(set) lazy var style = SoramitsuStyle(palette: theme.palette,
                                         radii: DefaultRadii(),
                                         shady: DefaultShady(),
                                         layout: DefaultLayout(),
                                         statusBar: theme.statusBar)
	private let storage: ThemeStorage

	private lazy var systemTheme: SoramitsuThemeType = currentSystemTheme
	private var mode: SoramitsuThemeMode
	private var currentSystemTheme: SoramitsuThemeType {
		if #available(iOS 13.0, *) {
			switch UITraitCollection.current.userInterfaceStyle {
			case .light, .unspecified:
				return .light
			case .dark:
				return .dark
			@unknown default:
				return .light
			}
		} else {
			return .light
		}
	}

	init(storage: ThemeStorage) {
        self.storage = storage
        if let theme = storage.theme {
            mode = .manual(theme)
        } else {
            mode = .system
        }

		NotificationCenter.default.addObserver(self,
											   selector: #selector(appMovedToForeground),
											   name: UIApplication.didBecomeActiveNotification,
											   object: nil)
	}

	private func updateTheme() {
		style.apply(theme.palette)
		style.apply(theme.statusBar)
	}

	@objc private func appMovedToForeground() {
		switch mode {
		case .system:
			if systemTheme != currentSystemTheme {
				systemTheme = currentSystemTheme
				updateTheme()
			}
		default: break
		}
	}
}
