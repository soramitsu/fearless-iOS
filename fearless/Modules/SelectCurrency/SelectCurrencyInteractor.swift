import UIKit
import SoraKeystore
import RobinHood
import SSFModels

final class SelectCurrencyInteractor {
    // MARK: - Private properties

    private let selectedMetaAccount: MetaAccountModel
    private let jsonDataProviderFactory: JsonDataProviderFactoryProtocol
    private let eventCenter: EventCenterProtocol

    private var fiatInfoProvider: AnySingleValueProvider<[Currency]>?

    private weak var output: SelectCurrencyInteractorOutput?

    init(
        selectedMetaAccount: MetaAccountModel,
        jsonDataProviderFactory: JsonDataProviderFactoryProtocol,
        eventCenter: EventCenterProtocol
    ) {
        self.selectedMetaAccount = selectedMetaAccount
        self.jsonDataProviderFactory = jsonDataProviderFactory
        self.eventCenter = eventCenter
    }

    private func subscribeToFiats() {
        fiatInfoProvider = nil

        guard let fiatUrl = ApplicationConfig.shared.fiatsURL else { return }
        fiatInfoProvider = try? jsonDataProviderFactory.getJson(for: fiatUrl)

        let updateClosure: ([DataProviderChange<[Currency]>]) -> Void = { [weak self] changes in
            if let result = changes.reduceToLastChange() {
                self?.output?.didRecieve(supportedСurrencies: .success(result))
            }
        }

        let failureClosure: (Error) -> Void = { [weak self] error in
            self?.output?.didRecieve(supportedСurrencies: .failure(error))
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: true,
            waitsInProgressSyncOnAdd: false
        )

        fiatInfoProvider?.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )
    }

    private func save(_ currency: Currency) {
        let updatedAccount = selectedMetaAccount.replacingCurrency(currency)
        SelectedWalletSettings.shared.performSave(value: updatedAccount) { [weak self] result in
            switch result {
            case let .success(account):
                self?.eventCenter.notify(with: MetaAccountModelChangedEvent(account: account))
            case .failure:
                break
            }
        }
    }
}

// MARK: - SelectCurrencyInteractorInput

extension SelectCurrencyInteractor: SelectCurrencyInteractorInput {
    func setup(with output: SelectCurrencyInteractorOutput) {
        self.output = output
        output.didRecieve(selectedCurrency: selectedMetaAccount.selectedCurrency)
        subscribeToFiats()
    }

    func didSelect(_ currency: Currency) {
        save(currency)
    }
}
