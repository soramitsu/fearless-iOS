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
    private var validatorProvider: AnyDataProvider<DecodedValidator>?
    private var nominatorProvider: AnyDataProvider<DecodedNomination>?
    private var ledgerProvider: AnyDataProvider<DecodedLedgerInfo>?

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

    private func didReceive(electionStatus: ElectionStatus?) {
        switch electionStatus {
        case .close:
            logger.debug("Election status: close")
        case .open(let blockNumber):
            logger.debug("Election status: open from \(blockNumber)")
        case .none:
            logger.debug("No election status set")
        }

    }

    private func didReceive(stashItem: StashItem?) {
        if let stashItem = stashItem {
            logger.debug("Stash: \(stashItem.stash)")
            logger.debug("Controller: \(stashItem.controller)")

            subscribeToLedger(address: stashItem.controller)
            subscribeToNominator(address: stashItem.stash)
            subscribeToValidator(address: stashItem.stash)
        } else {
            logger.debug("No stash found")
        }
    }

    private func didReceive(ledgerInfo: DyStakingLedger?) {
        if let ledgerInfo = ledgerInfo {
            logger.debug("Did receive ledger info: \(ledgerInfo)")
        } else {
            logger.debug("No ledger info received")
        }
    }

    private func didReceive(nomination: Nomination?) {
        if let nomination = nomination {
            logger.debug("Did receive nomination: \(nomination)")
        } else {
            logger.debug("No nomination received")
        }
    }

    private func didReceive(validator: ValidatorPrefs?) {
        if let validator = validator {
            logger.debug("Did receive validator: \(validator)")
        } else {
            logger.debug("No validator received")
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
            let balanceItem = changes.reduceToLastChange()?.item
            self?.presenter.didReceive(balance: balanceItem?.data)
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
        clearLedgerProvider()
        clearNominatorProvider()
        clearValidatorProvider()

        stashControllerProvider?.removeObserver(self)
        stashControllerProvider = nil
    }

    private func subscribeToStashControllerProvider() {
        guard stashControllerProvider == nil, let selectedAccount = currentAccount else {
            return
        }

        let provider = substrateProviderFactory.createStashItemProvider(for: selectedAccount.address)

        let changesClosure: ([DataProviderChange<StashItem>]) -> Void = { [weak self] (changes) in
            let stashItem = changes.reduceToLastChange()
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

    private func clearLedgerProvider() {
        ledgerProvider?.removeObserver(self)
        ledgerProvider = nil
    }

    func subscribeToLedger(address: String) {
        guard ledgerProvider == nil else {
            return
        }

        guard let ledgerProvider = try? providerFactory
                .getLedgerInfoProvider(for: address, runtimeService: runtimeService) else {
            logger.error("Can't create ledger provider")
            return
        }

        self.ledgerProvider = ledgerProvider

        let updateClosure = { [weak self] (changes: [DataProviderChange<DecodedLedgerInfo>]) in
            let ledgerInfo = changes.reduceToLastChange()?.item
            self?.didReceive(ledgerInfo: ledgerInfo)
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.presenter.didReceive(error: error)
            return
        }

        let options = DataProviderObserverOptions(alwaysNotifyOnRefresh: false,
                                                  waitsInProgressSyncOnAdd: false)
        ledgerProvider.addObserver(self,
                                   deliverOn: .main,
                                   executing: updateClosure,
                                   failing: failureClosure,
                                   options: options)
    }


    private func clearNominatorProvider() {
        nominatorProvider?.removeObserver(self)
        nominatorProvider = nil
    }

    func subscribeToNominator(address: String) {
        guard nominatorProvider == nil else {
            return
        }
        
        guard let nominatorProvider = try? providerFactory
                .getNominationProvider(for: address, runtimeService: runtimeService) else {
            logger.error("Can't create nominator provider")
            return
        }

        self.nominatorProvider = nominatorProvider

        let updateClosure = { [weak self] (changes: [DataProviderChange<DecodedNomination>]) in
            let nomination = changes.reduceToLastChange()?.item
            self?.didReceive(nomination: nomination)
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.presenter.didReceive(error: error)
            return
        }

        let options = DataProviderObserverOptions(alwaysNotifyOnRefresh: false,
                                                  waitsInProgressSyncOnAdd: false)
        nominatorProvider.addObserver(self,
                                      deliverOn: .main,
                                      executing: updateClosure,
                                      failing: failureClosure,
                                      options: options)
    }

    private func clearValidatorProvider() {
        validatorProvider?.removeObserver(self)
        validatorProvider = nil
    }

    func subscribeToValidator(address: String) {
        guard validatorProvider == nil else {
            return
        }

        guard let validatorProvider = try? providerFactory
                .getValidatorProvider(for: address, runtimeService: runtimeService) else {
            logger.error("Can't create validator provider")
            return
        }

        self.validatorProvider = validatorProvider

        let updateClosure = { [weak self] (changes: [DataProviderChange<DecodedValidator>]) in
            let validator = changes.reduceToLastChange()?.item
            self?.didReceive(validator: validator)
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.presenter.didReceive(error: error)
            return
        }

        let options = DataProviderObserverOptions(alwaysNotifyOnRefresh: false,
                                                  waitsInProgressSyncOnAdd: false)
        validatorProvider.addObserver(self,
                                      deliverOn: .main,
                                      executing: updateClosure,
                                      failing: failureClosure,
                                      options: options)
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
            let electionStatus = changes.reduceToLastChange()?.item
            self?.didReceive(electionStatus: electionStatus)
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
