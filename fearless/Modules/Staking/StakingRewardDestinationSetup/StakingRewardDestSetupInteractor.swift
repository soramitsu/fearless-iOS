import SoraKeystore
import RobinHood
import IrohaCrypto

final class StakingRewardDestSetupInteractor: AccountFetching {
    weak var presenter: StakingRewardDestSetupInteractorOutputProtocol!

    let selectedAccountAddress: AccountAddress
    let singleValueProviderFactory: SingleValueProviderFactoryProtocol
    let extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol
    let substrateProviderFactory: SubstrateDataProviderFactoryProtocol
    let calculatorService: RewardCalculatorServiceProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    let operationManager: OperationManagerProtocol
    let accountRepository: AnyDataProviderRepository<AccountItem>
    let feeProxy: ExtrinsicFeeProxyProtocol
    let assetId: WalletAssetId
    let chain: Chain

    private var electionStatusProvider: AnyDataProvider<DecodedElectionStatus>?
    private var stashItemProvider: StreamableProvider<StashItem>?
    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var accountInfoProvider: AnyDataProvider<DecodedAccountInfo>?
    private var payeeProvider: AnyDataProvider<DecodedPayee>?
    private var ledgerProvider: AnyDataProvider<DecodedLedgerInfo>?
    private var nominationProvider: AnyDataProvider<DecodedNomination>?

    private var stashItem: StashItem?

    private var extrinisicService: ExtrinsicServiceProtocol?

    private lazy var callFactory = SubstrateCallFactory()
    private lazy var addressFactory = SS58AddressFactory()

    init(
        selectedAccountAddress: AccountAddress,
        singleValueProviderFactory: SingleValueProviderFactoryProtocol,
        extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol,
        substrateProviderFactory: SubstrateDataProviderFactoryProtocol,
        calculatorService: RewardCalculatorServiceProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        operationManager: OperationManagerProtocol,
        accountRepository: AnyDataProviderRepository<AccountItem>,
        feeProxy: ExtrinsicFeeProxyProtocol,
        assetId: WalletAssetId,
        chain: Chain
    ) {
        self.selectedAccountAddress = selectedAccountAddress
        self.singleValueProviderFactory = singleValueProviderFactory
        self.extrinsicServiceFactory = extrinsicServiceFactory
        self.substrateProviderFactory = substrateProviderFactory
        self.calculatorService = calculatorService
        self.runtimeService = runtimeService
        self.operationManager = operationManager
        self.accountRepository = accountRepository
        self.feeProxy = feeProxy
        self.assetId = assetId
        self.chain = chain
    }

    private func setupExtrinsicServiceIfNeeded(_ accountItem: AccountItem) {
        guard extrinisicService == nil else {
            return
        }

        extrinisicService = extrinsicServiceFactory.createService(accountItem: accountItem)

        estimateFee()
    }

    private func provideRewardCalculator() {
        let operation = calculatorService.fetchCalculatorOperation()

        operation.completionBlock = {
            DispatchQueue.main.async { [weak self] in
                do {
                    let engine = try operation.extractNoCancellableResultData()
                    self?.presenter.didReceiveCalculator(result: .success(engine))
                } catch {
                    self?.presenter.didReceiveCalculator(result: .failure(error))
                }
            }
        }

        operationManager.enqueue(
            operations: [operation],
            in: .transient
        )
    }
}

extension StakingRewardDestSetupInteractor: StakingRewardDestSetupInteractorInputProtocol {
    func setup() {
        stashItemProvider = subscribeToStashItemProvider(for: selectedAccountAddress)

        priceProvider = subscribeToPriceProvider(for: assetId)
        electionStatusProvider = subscribeToElectionStatusProvider(chain: chain, runtimeService: runtimeService)

        provideRewardCalculator()

        feeProxy.delegate = self
    }

    func estimateFee() {
        guard let extrinsicService = extrinisicService else {
            presenter.didReceiveFee(result: .failure(CommonError.undefined))
            return
        }

        do {
            let accountId = try addressFactory.accountId(from: selectedAccountAddress)

            let setPayeeCall = callFactory.setPayee(for: .account(accountId))

            feeProxy.estimateFee(
                using: extrinsicService,
                reuseIdentifier: setPayeeCall.callName
            ) { builder in
                try builder.adding(call: setPayeeCall)
            }
        } catch {
            presenter.didReceiveFee(result: .failure(error))
        }
    }

    func fetchPayoutAccounts() {
        fetchAllAccounts(from: accountRepository, operationManager: operationManager) { [weak self] result in
            self?.presenter.didReceiveAccounts(result: result)
        }
    }
}

extension StakingRewardDestSetupInteractor: SubstrateProviderSubscriber,
    SubstrateProviderSubscriptionHandler, SingleValueProviderSubscriber,
    SingleValueSubscriptionHandler, AnyProviderAutoCleaning {
    func handleStashItem(result: Result<StashItem?, Error>) {
        do {
            stashItem = try result.get()

            clear(dataProvider: &ledgerProvider)
            clear(dataProvider: &payeeProvider)
            clear(dataProvider: &accountInfoProvider)
            clear(dataProvider: &nominationProvider)

            presenter.didReceiveStashItem(result: result)

            if let stashItem = stashItem {
                ledgerProvider = subscribeToLedgerInfoProvider(
                    for: stashItem.controller,
                    runtimeService: runtimeService
                )

                payeeProvider = subscribeToPayeeProvider(
                    for: stashItem.stash,
                    runtimeService: runtimeService
                )

                nominationProvider = subscribeToNominationProvider(
                    for: stashItem.stash,
                    runtimeService: runtimeService
                )

                accountInfoProvider = subscribeToAccountInfoProvider(
                    for: stashItem.controller,
                    runtimeService: runtimeService
                )

                fetchAccount(
                    for: stashItem.stash,
                    from: accountRepository,
                    operationManager: operationManager
                ) { [weak self] result in
                    if case let .success(maybeStash) = result, let stash = maybeStash {
                        self?.setupExtrinsicServiceIfNeeded(stash)
                    }

                    self?.presenter.didReceiveStash(result: result)
                }

                fetchAccount(
                    for: stashItem.controller,
                    from: accountRepository,
                    operationManager: operationManager
                ) { [weak self] result in
                    if case let .success(maybeController) = result, let controller = maybeController {
                        self?.setupExtrinsicServiceIfNeeded(controller)
                    }

                    self?.presenter.didReceiveController(result: result)
                }

            } else {
                presenter.didReceiveStakingLedger(result: .success(nil))
                presenter.didReceiveController(result: .success(nil))
            }

        } catch {
            presenter.didReceiveStashItem(result: .failure(error))
            presenter.didReceiveController(result: .success(nil))
            presenter.didReceiveStakingLedger(result: .failure(error))
        }
    }

    func handlePrice(result: Result<PriceData?, Error>, for _: WalletAssetId) {
        presenter.didReceivePriceData(result: result)
    }

    func handleLedgerInfo(result: Result<StakingLedger?, Error>, address _: AccountAddress) {
        presenter.didReceiveStakingLedger(result: result)
    }

    func handleNomination(result: Result<Nomination?, Error>, address _: AccountAddress) {
        presenter.didReceiveNomination(result: result)
    }

    func handleAccountInfo(result: Result<AccountInfo?, Error>, address _: AccountAddress) {
        presenter.didReceiveAccountInfo(result: result)
    }

    func handlePayee(result: Result<RewardDestinationArg?, Error>, address _: AccountAddress) {
        do {
            guard let payee = try result.get(), let stashItem = stashItem else {
                presenter.didReceiveRewardDestinationAccount(result: .failure(CommonError.undefined))
                return
            }

            let rewardDestination = try RewardDestination(payee: payee, stashItem: stashItem, chain: chain)

            switch rewardDestination {
            case .restake:
                presenter.didReceiveRewardDestinationAccount(result: .success(.restake))
            case let .payout(account):
                fetchAccount(
                    for: account,
                    from: accountRepository,
                    operationManager: operationManager
                ) { [weak self] result in
                    switch result {
                    case let .success(accountItem):
                        if let accountItem = accountItem {
                            self?.presenter.didReceiveRewardDestinationAccount(
                                result: .success(.payout(account: accountItem))
                            )
                        } else {
                            self?.presenter.didReceiveRewardDestinationAddress(
                                result: .success(.payout(account: account))
                            )
                        }
                    case let .failure(error):
                        self?.presenter.didReceiveRewardDestinationAccount(result: .failure(error))
                    }
                }
            }
        } catch {
            presenter.didReceiveRewardDestinationAccount(result: .failure(error))
        }
    }

    func handleElectionStatus(result: Result<ElectionStatus?, Error>, chain _: Chain) {
        presenter.didReceiveElectionStatus(result: result)
    }
}

extension StakingRewardDestSetupInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        presenter.didReceiveFee(result: result)
    }
}
