import UIKit
import SoraKeystore

final class SelectCurrencyInteractor {
    // MARK: - Private properties

    private weak var output: SelectCurrencyInteractorOutput?
    private let settings: SettingsManagerProtocol

    init(settings: SettingsManagerProtocol) {
        self.settings = settings
    }

    private func provideSelectedCurrency() {
        output?.didRecieve(selectedCurrency: settings.selectedCurrency)
    }
}

// MARK: - SelectCurrencyInteractorInput

extension SelectCurrencyInteractor: SelectCurrencyInteractorInput {
    func setup(with output: SelectCurrencyInteractorOutput) {
        self.output = output
        provideSelectedCurrency()
    }

    func didSelect(_ currency: Currency) {
        settings.selectedCurrency = currency
    }
}
