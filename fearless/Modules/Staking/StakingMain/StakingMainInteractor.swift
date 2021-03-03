import Foundation
import SoraKeystore
import RobinHood
import FearlessUtils

final class StakingMainInteractor {
    weak var presenter: StakingMainInteractorOutputProtocol!

    private let repository: AnyDataProviderRepository<AccountItem>
    private let priceProvider: SingleValueProvider<PriceData>
    private let balanceProvider: DataProvider<DecodedAccountInfo>
    private let settings: SettingsManagerProtocol
    private let eventCenter: EventCenterProtocol
    private let calculatorService: RewardCalculatorServiceProtocol
    private let operationManager: OperationManagerProtocol
    private let logger: LoggerProtocol

    init(repository: AnyDataProviderRepository<AccountItem>,
         priceProvider: SingleValueProvider<PriceData>,
         balanceProvider: DataProvider<DecodedAccountInfo>,
         settings: SettingsManagerProtocol,
         eventCenter: EventCenterProtocol,
         calculatorService: RewardCalculatorServiceProtocol,
         operationManager: OperationManagerProtocol,
         logger: Logger) {
        self.repository = repository
        self.priceProvider = priceProvider
        self.balanceProvider = balanceProvider
        self.settings = settings
        self.eventCenter = eventCenter
        self.calculatorService = calculatorService
        self.operationManager = operationManager
        self.logger = logger
    }

    private func updateSelectedAccount() {
        guard let address = settings.selectedAccount?.address else {
            return
        }

        presenter.didReceive(selectedAddress: address)
    }

    private func provideRewardCalculator() {
        let operation = calculatorService.fetchCalculatorOperation()

        operation.completionBlock = {
            DispatchQueue.main.async { [weak self] in
                do {
                    let engine = try operation.extractNoCancellableResultData()
                    self?.presenter.didReceive(calculator: engine)
                } catch {
                    self?.presenter.didReceive(calculatorError: error)
                }
            }
        }

        operationManager.enqueue(operations: [operation],
                                 in: .transient)
    }

    private func subscribeToPriceChanges() {
        let updateClosure = { [weak self] (changes: [DataProviderChange<PriceData>]) in
            if changes.isEmpty {
                self?.presenter.didReceive(price: nil)
            } else {
                for change in changes {
                    switch change {
                    case .insert(let item), .update(let item):
                        self?.presenter.didReceive(price: item)
                    case .delete:
                        self?.presenter.didReceive(price: nil)
                    }
                }
            }
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.presenter.didReceive(error: error)
            return
        }

        let options = DataProviderObserverOptions(alwaysNotifyOnRefresh: false,
                                                  waitsInProgressSyncOnAdd: false)
        priceProvider.addObserver(self,
                                  deliverOn: .main,
                                  executing: updateClosure,
                                  failing: failureClosure,
                                  options: options)
    }

    private func subscribeToAccountChanges() {
        let updateClosure = { [weak self] (changes: [DataProviderChange<DecodedAccountInfo>]) in
            if changes.isEmpty {
                self?.presenter.didReceive(balance: nil)
            } else {
                for change in changes {
                    switch change {
                    case .insert(let wrapped), .update(let wrapped):
                        self?.presenter.didReceive(balance: wrapped.item.data)
                    case .delete:
                        self?.presenter.didReceive(price: nil)
                    }
                }
            }
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.presenter.didReceive(error: error)
            return
        }

        let options = DataProviderObserverOptions(alwaysNotifyOnRefresh: false,
                                                  waitsInProgressSyncOnAdd: false)
        balanceProvider.addObserver(self,
                                    deliverOn: .main,
                                    executing: updateClosure,
                                    failing: failureClosure,
                                    options: options)
    }
}

extension StakingMainInteractor: StakingMainInteractorInputProtocol {
    func setup() {
        subscribeToPriceChanges()
        subscribeToAccountChanges()
        provideRewardCalculator()
        eventCenter.add(observer: self, dispatchIn: .main)

        updateSelectedAccount()
    }
}

extension StakingMainInteractor: EventVisitorProtocol {
    func processSelectedAccountChanged(event: SelectedAccountChanged) {
        updateSelectedAccount()
    }
}
