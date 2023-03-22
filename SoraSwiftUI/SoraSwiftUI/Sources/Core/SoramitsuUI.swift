import UIKit

public final class SoramitsuUI {

    public static let shared: SoramitsuUI = {
        let storage = ThemeStorage()
        let manager = ThemeManager(storage: storage)
        let soraUI = SoramitsuUI(themeManager: manager)
        return soraUI
    }()

    public var theme: SoramitsuThemeType {
        return themeManager.theme
    }

    public var themeMode: SoramitsuThemeMode {
        get { themeManager.themeMode }
        set { themeManager.themeMode = newValue }
    }

    public static var updates: SoramitsuObservable {
        return shared.style
    }

    var style: SoramitsuStyle {
        return themeManager.style
    }

    private let themeManager: ThemeManager

    private init(themeManager: ThemeManager) {
        self.themeManager = themeManager
    }
}
