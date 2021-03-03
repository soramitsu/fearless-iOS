import Foundation
import SoraKeystore
import RobinHood
import FearlessUtils

final class StakingMainInteractor {
    weak var presenter: StakingMainInteractorOutputProtocol!

    private let providerFactory: SingleValueProviderFactoryProtocol
    private let settings: SettingsManagerProtocol
    private let eventCenter: EventCenterProtocol
    private let runtimeService: RuntimeCodingServiceProtocol
    private let calculatorService: RewardCalculatorServiceProtocol
    private let operationManager: OperationManagerProtocol
    private let primitiveFactory: WalletPrimitiveFactoryProtocol
    private let logger: LoggerProtocol

    private var priceProvider: SingleValueProvider<PriceData>?
    private var balanceProvider: DataProvider<DecodedAccountInfo>?

    private var currentAccount: AccountItem?
    private var currentConnection: ConnectionItem?

    init(providerFactory: SingleValueProviderFactoryProtocol,
         settings: SettingsManagerProtocol,
         eventCenter: EventCenterProtocol,
         primitiveFactory: WalletPrimitiveFactoryProtocol,
         calculatorService: RewardCalculatorServiceProtocol,
         runtimeService: RuntimeCodingServiceProtocol,
         operationManager: OperationManagerProtocol,
         logger: Logger) {
        self.providerFactory = providerFactory
        self.settings = settings
        self.eventCenter = eventCenter
        self.primitiveFactory = primitiveFactory
        self.calculatorService = calculatorService
        self.runtimeService = runtimeService
        self.operationManager = operationManager
        self.logger = logger
    }

    private func provideSelectedAccount() {
        guard let address = currentAccount?.address else {
            return
        }

        presenter.didReceive(selectedAddress: address)
    }

    private func provideNewChain() {
        guard let chain = currentConnection?.type.chain else {
            return
        }

        presenter.didReceive(newChain: chain)
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

    private func clearPriceProvider() {
        priceProvider?.removeObserver(self)
        priceProvider = nil
    }

    private func subscribeToPriceChanges() {
        guard priceProvider == nil, let connection = currentConnection else {
            return
        }

        let asset = primitiveFactory.createAssetForAddressType(connection.type)

        guard let assetId = WalletAssetId(rawValue: asset.identifier) else {
            logger.error("Can't create asset id")
            return
        }

        priceProvider = providerFactory.getPriceProvider(for: assetId)

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
        priceProvider?.addObserver(self,
                                  deliverOn: .main,
                                  executing: updateClosure,
                                  failing: failureClosure,
                                  options: options)
    }

    private func clearAccountProvider() {
        balanceProvider?.removeObserver(self)
        balanceProvider = nil
    }

    private func subscribeToAccountChanges() {
        guard balanceProvider == nil, let selectedAccount = currentAccount else {
            return
        }

        guard let balanceProvider = try? providerFactory
                .getAccountProvider(for: selectedAccount.address,
                                    runtimeService: runtimeService) else {
            logger.error("Can't create balance provider")
            return
        }

        self.balanceProvider = balanceProvider

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

    private func updateAccountAndChainIfNeeded() -> Bool {
        let hasChanges = (currentAccount != settings.selectedAccount) ||
            (currentConnection != settings.selectedConnection)

        if settings.selectedAccount != currentAccount {
            self.currentAccount = settings.selectedAccount

            clearAccountProvider()
            subscribeToAccountChanges()

            provideSelectedAccount()
        }

        if settings.selectedConnection != currentConnection {
            self.currentConnection = settings.selectedConnection

            clearPriceProvider()
            subscribeToPriceChanges()

            provideNewChain()
        }

        return hasChanges
    }
}

extension StakingMainInteractor: StakingMainInteractorInputProtocol {
    func setup() {
        self.currentAccount = settings.selectedAccount
        self.currentConnection = settings.selectedConnection

        provideSelectedAccount()
        provideNewChain()

        subscribeToPriceChanges()
        subscribeToAccountChanges()
        provideRewardCalculator()
        eventCenter.add(observer: self, dispatchIn: .main)
    }
}

extension StakingMainInteractor: EventVisitorProtocol {
    func processSelectedAccountChanged(event: SelectedAccountChanged) {
        if updateAccountAndChainIfNeeded() {
            provideRewardCalculator()
        }
    }

    func processSelectedConnectionChanged(event: SelectedConnectionChanged) {
        if updateAccountAndChainIfNeeded() {
            provideRewardCalculator()
        }
    }
}
