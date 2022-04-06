import UIKit
import SoraFoundation
import SoraKeystore

final class EducationStoriesAssembly {
    static func configureModule() -> EducationStoriesViewProtocol? {
        let localizationManager = LocalizationManager.shared
        let router = EducationStoriesRouter()
        let userDefaultsStorage = SettingsManager.shared
        let keychain = Keychain()
        let startViewHelper = StartViewHelper(
            keystore: keychain,
            selectedWallerSettings: SelectedWalletSettings.shared,
            userDefaultsStorage: SettingsManager.shared
        )

        let presenter = EducationStoriesPresenter(
            userDefaultsStorage: userDefaultsStorage,
            storiesFactory: EducationStoriesFactoryImpl(),
            router: router,
            startViewHelper: startViewHelper,
            localizationManager: localizationManager
        )

        let view = EducationStoriesViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        return view
    }
}
