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
    private let rewardCalculatorService: RewardCalculatorServiceProtocol
    private let operationManager: OperationManagerProtocol
    private let logger: LoggerProtocol

    init(repository: AnyDataProviderRepository<AccountItem>,
         priceProvider: SingleValueProvider<PriceData>,
         balanceProvider: DataProvider<DecodedAccountInfo>,
         settings: SettingsManagerProtocol,
         eventCenter: EventCenterProtocol,
         rewardCalculatorService: RewardCalculatorServiceProtocol,
         operationManager: OperationManagerProtocol,
         logger: Logger) {
        self.repository = repository
        self.priceProvider = priceProvider
        self.balanceProvider = balanceProvider
        self.settings = settings
        self.eventCenter = eventCenter
        self.rewardCalculatorService = rewardCalculatorService
        self.operationManager = operationManager
        self.logger = logger
    }

    private func updateSelectedAccount() {
        guard let address = settings.selectedAccount?.address else {
            return
        }

        presenter.didReceive(selectedAddress: address)
    }

    private func getCalculator() {
        let calculatorOperation = rewardCalculatorService.fetchCalculatorOperation()

        calculatorOperation.completionBlock = {
            DispatchQueue.main.async {
                switch calculatorOperation.result {
                case .success(let calculator):
                    self.presenter.didRecieve(calculator: calculator)
                case .failure(let error):
                    self.logger.error("Calculator fetch error: \(error)")
                case .none:
                    self.logger.warning("Calculator info fetch cancelled")
                }
            }
        }

        operationManager.enqueue(operations: [calculatorOperation],
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
        getCalculator()
        eventCenter.add(observer: self, dispatchIn: .main)

        updateSelectedAccount()
    }
}

extension StakingMainInteractor: EventVisitorProtocol {
    func processSelectedAccountChanged(event: SelectedAccountChanged) {
        updateSelectedAccount()
    }
}
