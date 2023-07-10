import Foundation
import SoraFoundation
import SoraKeystore

final class SelectedLanguageMigrator: Migrating {
    let localizationManager: LocalizationManagerProtocol

    init(
        localizationManager: LocalizationManagerProtocol
    ) {
        self.localizationManager = localizationManager
    }

    func migrate() throws {
        let availableLocalizations = localizationManager.availableLocalizations

        if
            !availableLocalizations.contains(localizationManager.selectedLocalization),
            let availableLocalization = availableLocalizations.first {
            localizationManager.selectedLocalization = availableLocalization
        }
    }
}
