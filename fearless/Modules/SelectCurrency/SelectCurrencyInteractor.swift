import UIKit
import SoraKeystore
import RobinHood

final class SelectCurrencyInteractor {
    // MARK: - Private properties

    private let selectedMetaAccount: MetaAccountModel
    private let repository: AnyDataProviderRepository<MetaAccountModel>
    private let jsonDataProviderFactory: JsonDataProviderFactoryProtocol
    private let eventCenter: EventCenterProtocol

    private var fiatInfoProvider: AnySingleValueProvider<[Currency]>?
    private let operationQueue: OperationQueue

    private weak var output: SelectCurrencyInteractorOutput?

    init(
        selectedMetaAccount: MetaAccountModel,
        repository: AnyDataProviderRepository<MetaAccountModel>,
        jsonDataProviderFactory: JsonDataProviderFactoryProtocol,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue
    ) {
        self.selectedMetaAccount = selectedMetaAccount
        self.repository = repository
        self.jsonDataProviderFactory = jsonDataProviderFactory
        self.eventCenter = eventCenter
        self.operationQueue = operationQueue
    }

    private func subscribeToFiats() {
        fiatInfoProvider = nil

        guard let fiatUrl = ApplicationConfig.shared.fiatsURL else { return }
        fiatInfoProvider = jsonDataProviderFactory.getJson(for: fiatUrl)

        let updateClosure: ([DataProviderChange<[Currency]>]) -> Void = { [weak self] changes in
            if var result = changes.reduceToLastChange() {
                guard
                    let selectedCurrency = self?.selectedMetaAccount.selectedCurrency,
                    let selectedCurrencyIndex = result.firstIndex(where: { $0.id == selectedCurrency.id })
                else {
                    return
                }

                result[selectedCurrencyIndex] = selectedCurrency
                self?.output?.didRecieve(supportedCurrencys: .success(result))
            }
        }

        let failureClosure: (Error) -> Void = { [weak self] error in
            self?.output?.didRecieve(supportedCurrencys: .failure(error))
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

        let operation = repository.saveOperation {
            [updatedAccount]
        } _: {
            []
        }

        operation.completionBlock = { [weak self] in
            SelectedWalletSettings.shared.performSave(value: updatedAccount) { result in
                switch result {
                case let .success(account):
                    self?.eventCenter.notify(with: AssetsListChangedEvent(account: account))
                case .failure:
                    break
                }
            }
        }

        operationQueue.addOperation(operation)
    }
}

// MARK: - SelectCurrencyInteractorInput

extension SelectCurrencyInteractor: SelectCurrencyInteractorInput {
    func setup(with output: SelectCurrencyInteractorOutput) {
        self.output = output
        subscribeToFiats()
    }

    func didSelect(_ currency: Currency) {
        save(currency)
    }
}
