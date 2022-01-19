import SoraKeystore
import RobinHood
import IrohaCrypto
import FearlessUtils

final class StakingRewardDestSetupInteractor: AccountFetching {
    weak var presenter: StakingRewardDestSetupInteractorOutputProtocol!

    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol

    private let accountRepository: AnyDataProviderRepository<MetaAccountModel>
    var extrinsicService: ExtrinsicServiceProtocol?
    let substrateProviderFactory: SubstrateDataProviderFactoryProtocol
    let calculatorService: RewardCalculatorServiceProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    let operationManager: OperationManagerProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol
    let asset: AssetModel
    let chain: ChainModel
    let selectedAccount: MetaAccountModel
    let connection: JSONRPCEngine

    private var stashItemProvider: StreamableProvider<StashItem>?
    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var accountInfoProvider: AnyDataProvider<DecodedAccountInfo>?
    private var payeeProvider: AnyDataProvider<DecodedPayee>?
    private var ledgerProvider: AnyDataProvider<DecodedLedgerInfo>?
    private var nominationProvider: AnyDataProvider<DecodedNomination>?

    private var stashItem: StashItem?

    private lazy var callFactory = SubstrateCallFactory()
    private lazy var addressFactory = SS58AddressFactory()

    init(
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        substrateProviderFactory: SubstrateDataProviderFactoryProtocol,
        calculatorService: RewardCalculatorServiceProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        operationManager: OperationManagerProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        asset: AssetModel,
        chain: ChainModel,
        selectedAccount: MetaAccountModel,
        connection: JSONRPCEngine
    ) {
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.substrateProviderFactory = substrateProviderFactory
        self.calculatorService = calculatorService
        self.runtimeService = runtimeService
        self.operationManager = operationManager
        self.feeProxy = feeProxy
        self.asset = asset
        self.chain = chain
        self.selectedAccount = selectedAccount
        self.accountRepository = accountRepository
        self.connection = connection
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

    private func setupExtrinsicServiceIfNeeded(_ accountItem: ChainAccountResponse) {
        guard extrinsicService == nil else {
            return
        }

        extrinsicService = ExtrinsicService(
            accountId: accountItem.accountId,
            chainFormat: chain.chainFormat,
            cryptoType: accountItem.cryptoType,
            runtimeRegistry: runtimeService,
            engine: connection,
            operationManager: operationManager
        )

        estimateFee()
    }
}

extension StakingRewardDestSetupInteractor: StakingRewardDestSetupInteractorInputProtocol {
    func setup() {
        calculatorService.setup()

        if let address = selectedAccount.fetch(for: chain.accountRequest())?.toAddress() {
            stashItemProvider = subscribeStashItemProvider(for: address)
        }

        if let priceId = asset.priceId {
            priceProvider = subscribeToPrice(for: priceId)
        }

        provideRewardCalculator()

        feeProxy.delegate = self
    }

    func estimateFee() {
        guard let extrinsicService = extrinsicService,
              let address = selectedAccount.fetch(for: chain.accountRequest())?.toAddress() else {
            return
        }
        do {
            let accountId = try addressFactory.accountId(fromAddress: address, type: chain.addressPrefix)

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
        fetchChainAccounts(
            chain: chain,
            from: accountRepository,
            operationManager: operationManager
        ) { [weak self] result in
            self?.presenter.didReceiveAccounts(result: result)
        }
    }
}

extension StakingRewardDestSetupInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAccountInfo(result: Result<AccountInfo?, Error>, accountId _: AccountId, chainId _: ChainModel.Id) {
        presenter.didReceiveAccountInfo(result: result)
    }
}

extension StakingRewardDestSetupInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        presenter.didReceivePriceData(result: result)
    }
}

extension StakingRewardDestSetupInteractor: StakingLocalStorageSubscriber, StakingLocalSubscriptionHandler {
    func handleStashItem(result: Result<StashItem?, Error>, for _: AccountAddress) {
        do {
            stashItem = try result.get()

            clear(dataProvider: &ledgerProvider)
            clear(dataProvider: &payeeProvider)
            clear(dataProvider: &accountInfoProvider)
            clear(dataProvider: &nominationProvider)

            presenter.didReceiveStashItem(result: result)

            if let stashItem = stashItem,
               let accountId = try? addressFactory.accountId(fromAddress: stashItem.stash, type: chain.addressPrefix) {
                ledgerProvider = subscribeLedgerInfo(for: accountId, chainId: chain.chainId)

                payeeProvider = subscribePayee(for: accountId, chainId: chain.chainId)

                nominationProvider = subscribeNomination(for: accountId, chainId: chain.chainId)

                accountInfoProvider = subscribeToAccountInfoProvider(for: accountId, chainId: chain.chainId)

                estimateFee()

                fetchChainAccount(
                    chain: chain,
                    address: stashItem.stash,
                    from: accountRepository,
                    operationManager: operationManager
                ) { [weak self] result in
                    if case let .success(stash) = result, let stash = stash {
                        self?.setupExtrinsicServiceIfNeeded(stash)
                    }

                    self?.presenter.didReceiveStash(result: result)
                }

                fetchChainAccount(
                    chain: chain,
                    address: stashItem.controller,
                    from: accountRepository,
                    operationManager: operationManager
                ) { [weak self] result in
                    if case let .success(controller) = result, let controller = controller {
                        self?.setupExtrinsicServiceIfNeeded(controller)
                    }

                    self?.presenter.didReceiveController(result: result)
                }

            } else {
                presenter.didReceiveStakingLedger(result: .success(nil))
                presenter.didReceiveAccountInfo(result: .success(nil))
                presenter.didReceiveRewardDestinationAccount(result: .success(nil))
                presenter.didReceiveNomination(result: .success(nil))
                presenter.didReceiveController(result: .success(nil))
            }

        } catch {
            presenter.didReceiveStashItem(result: .failure(error))
            presenter.didReceiveController(result: .failure(error))
            presenter.didReceiveStakingLedger(result: .failure(error))
            presenter.didReceiveAccountInfo(result: .failure(error))
            presenter.didReceiveRewardDestinationAccount(result: .failure(error))
            presenter.didReceiveNomination(result: .failure(error))
        }
    }

    func handleLedgerInfo(result: Result<StakingLedger?, Error>, accountId _: AccountId, chainId _: ChainModel.Id) {
        presenter.didReceiveStakingLedger(result: result)
    }

    func handleNomination(result: Result<Nomination?, Error>, accountId _: AccountId, chainId _: ChainModel.Id) {
        presenter.didReceiveNomination(result: result)
    }

    func handlePayee(result: Result<RewardDestinationArg?, Error>, accountId _: AccountId, chainId _: ChainModel.Id) {
        do {
            guard let payee = try result.get(), let stashItem = stashItem else {
                presenter.didReceiveRewardDestinationAccount(result: .failure(CommonError.undefined))
                return
            }

            let rewardDestination = try RewardDestination(payee: payee, stashItem: stashItem, chainFormat: chain.chainFormat)

            switch rewardDestination {
            case .restake:
                presenter.didReceiveRewardDestinationAccount(result: .success(.restake))
            case let .payout(account):
                fetchChainAccount(
                    chain: chain,
                    address: account,
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
}

extension StakingRewardDestSetupInteractor: AnyProviderAutoCleaning {}

extension StakingRewardDestSetupInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        presenter.didReceiveFee(result: result)
    }
}
