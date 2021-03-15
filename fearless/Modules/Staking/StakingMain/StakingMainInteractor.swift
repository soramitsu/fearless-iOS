import Foundation
import SoraKeystore
import RobinHood
import FearlessUtils

final class StakingMainInteractor {
    weak var presenter: StakingMainInteractorOutputProtocol!

    private let providerFactory: SingleValueProviderFactoryProtocol
    private let substrateProviderFactory: SubstrateDataProviderFactoryProtocol
    private let settings: SettingsManagerProtocol
    private let eventCenter: EventCenterProtocol
    private let runtimeService: RuntimeCodingServiceProtocol
    private let calculatorService: RewardCalculatorServiceProtocol
    private let operationManager: OperationManagerProtocol
    private let primitiveFactory: WalletPrimitiveFactoryProtocol
    private let logger: LoggerProtocol

    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var balanceProvider: AnyDataProvider<DecodedAccountInfo>?
    private var stashControllerProvider: StreamableProvider<StashItem>?
    private var electionStatusProvider: AnyDataProvider<DecodedElectionStatus>?

    private var currentAccount: AccountItem?
    private var currentConnection: ConnectionItem?

    init(providerFactory: SingleValueProviderFactoryProtocol,
         substrateProviderFactory: SubstrateDataProviderFactoryProtocol,
         settings: SettingsManagerProtocol,
         eventCenter: EventCenterProtocol,
         primitiveFactory: WalletPrimitiveFactoryProtocol,
         calculatorService: RewardCalculatorServiceProtocol,
         runtimeService: RuntimeCodingServiceProtocol,
         operationManager: OperationManagerProtocol,
         logger: Logger) {
        self.providerFactory = providerFactory
        self.substrateProviderFactory = substrateProviderFactory
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

    private func didReceive(electionStatus: ElectionStatus) {
        switch electionStatus {
        case .close:
            logger.debug("Election status: close")
        case .open(let blockNumber):
            logger.debug("Election status: open from \(blockNumber)")
        }

    }

    private func didReceive(stashItem: StashItem?) {
        if let stashItem = stashItem {
            logger.debug("Stash: \(stashItem.stash)")
            logger.debug("Controller: \(stashItem.controller)")
        } else {
            logger.debug("No stash found")
        }
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

    private func clearStashControllerProvider() {
        stashControllerProvider?.removeObserver(self)
        stashControllerProvider = nil
    }

    private func subscribeToStashControllerProvider() {
        guard stashControllerProvider == nil, let selectedAccount = currentAccount else {
            return
        }

        let provider = substrateProviderFactory.createStashItemProvider(for: selectedAccount.address)

        let changesClosure: ([DataProviderChange<StashItem>]) -> Void = { [weak self] (changes) in
            let stashItem: StashItem? = changes.reduce(nil) { (_, change) in
                switch change {
                case .insert(let newItem), .update(let newItem):
                    return newItem
                case .delete:
                    return nil
                }
            }

            self?.didReceive(stashItem: stashItem)
        }

        let failureClosure: (Error) -> Void = { [weak self] (error) in
            self?.presenter.didReceive(error: error)
            return
        }

        provider.addObserver(self,
                             deliverOn: .main,
                             executing: changesClosure,
                             failing: failureClosure,
                             options: StreamableProviderObserverOptions.substrateSource())

        self.stashControllerProvider = provider
    }

    private func clearElectionStatusProvider() {
        electionStatusProvider?.removeObserver(self)
        electionStatusProvider = nil
    }

    private func subscribeToElectionStatus() {
        guard electionStatusProvider == nil, let chain = currentConnection?.type.chain else {
            return
        }

        guard let electionStatusProvider = try? providerFactory
                .getElectionStatusProvider(chain: chain, runtimeService: runtimeService) else {
            logger.error("Can't create election status provider")
            return
        }

        self.electionStatusProvider = electionStatusProvider

        let updateClosure = { [weak self] (changes: [DataProviderChange<DecodedElectionStatus>]) in
            for change in changes {
                switch change {
                case .insert(let wrapped), .update(let wrapped):
                    self?.didReceive(electionStatus: wrapped.item)
                case .delete:
                    break
                }
            }
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.presenter.didReceive(error: error)
            return
        }

        let options = DataProviderObserverOptions(alwaysNotifyOnRefresh: false,
                                                  waitsInProgressSyncOnAdd: false)
        electionStatusProvider.addObserver(self,
                                           deliverOn: .main,
                                           executing: updateClosure,
                                           failing: failureClosure,
                                           options: options)
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
        subscribeToStashControllerProvider()
        subscribeToElectionStatus()
        provideRewardCalculator()

        eventCenter.add(observer: self, dispatchIn: .main)
    }
}

extension StakingMainInteractor: EventVisitorProtocol {
    func processSelectedAccountChanged(event: SelectedAccountChanged) {
        if updateAccountAndChainIfNeeded() {
            clearStashControllerProvider()
            subscribeToStashControllerProvider()

            provideRewardCalculator()
        }
    }

    func processSelectedConnectionChanged(event: SelectedConnectionChanged) {
        if updateAccountAndChainIfNeeded() {
            clearElectionStatusProvider()
            subscribeToElectionStatus()

            clearStashControllerProvider()
            subscribeToStashControllerProvider()

            provideRewardCalculator()
        }
    }
}
