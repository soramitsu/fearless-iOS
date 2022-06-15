import RobinHood
import IrohaCrypto
import BigInt
import SoraKeystore
import FearlessUtils

final class StakingBondMoreInteractor: AccountFetching {
    weak var presenter: StakingBondMoreInteractorOutputProtocol!

    let substrateProviderFactory: SubstrateDataProviderFactoryProtocol

    private let connection: JSONRPCEngine
    private let accountRepository: AnyDataProviderRepository<MetaAccountModel>
    private var extrinsicService: ExtrinsicServiceProtocol
    private let feeProxy: ExtrinsicFeeProxyProtocol
    private let runtimeService: RuntimeCodingServiceProtocol
    private let operationManager: OperationManagerProtocol
    private let chainAsset: ChainAsset
    private let selectedAccount: MetaAccountModel
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol
    let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol

    private var balanceProvider: AnyDataProvider<DecodedAccountInfo>?
    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var stashItemProvider: StreamableProvider<StashItem>?

    private lazy var callFactory = SubstrateCallFactory()

    init(
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        substrateProviderFactory: SubstrateDataProviderFactoryProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        operationManager: OperationManagerProtocol,
        chainAsset: ChainAsset,
        selectedAccount: MetaAccountModel,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        connection: JSONRPCEngine
    ) {
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.substrateProviderFactory = substrateProviderFactory
        self.extrinsicService = extrinsicService
        self.feeProxy = feeProxy
        self.runtimeService = runtimeService
        self.operationManager = operationManager
        self.chainAsset = chainAsset
        self.selectedAccount = selectedAccount
        self.accountRepository = accountRepository
        self.connection = connection
    }

    func handleStashAccountItem(_ account: ChainAccountResponse) {
        extrinsicService = ExtrinsicService(
            accountId: account.accountId,
            chainFormat: chainAsset.chain.chainFormat,
            cryptoType: account.cryptoType,
            runtimeRegistry: runtimeService,
            engine: connection,
            operationManager: operationManager
        )

        estimateFee()
    }
}

extension StakingBondMoreInteractor: StakingBondMoreInteractorInputProtocol {
    func setup() {
        if let address = selectedAccount.fetch(for: chainAsset.chain.accountRequest())?.toAddress() {
            stashItemProvider = subscribeStashItemProvider(for: address)
        }

        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId)
        }

        feeProxy.delegate = self

        estimateFee()
    }

    func estimateFee() {
        guard let amount = StakingConstants.maxAmount.toSubstrateAmount(
            precision: Int16(chainAsset.asset.precision)
        ) else {
            return
        }

        let bondExtra = callFactory.bondExtra(amount: amount)

        feeProxy.estimateFee(using: extrinsicService, reuseIdentifier: bondExtra.callName) { builder in
            try builder.adding(call: bondExtra)
        }
    }
}

extension StakingBondMoreInteractor: PriceLocalSubscriptionHandler, PriceLocalStorageSubscriber {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        presenter.didReceivePriceData(result: result)
    }
}

extension StakingBondMoreInteractor: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(result: Result<AccountInfo?, Error>, accountId _: AccountId, chainAsset _: ChainAsset) {
        presenter.didReceiveAccountInfo(result: result)
    }
}

extension StakingBondMoreInteractor: StakingLocalStorageSubscriber, StakingLocalSubscriptionHandler {
    func handleStashItem(result: Result<StashItem?, Error>, for _: AccountAddress) {
        do {
            let maybeStashItem = try result.get()

            accountInfoSubscriptionAdapter.reset()

            presenter.didReceiveStashItem(result: result)

            if let stashItem = maybeStashItem {
                fetchChainAccount(
                    chain: chainAsset.chain,
                    address: stashItem.stash,
                    from: accountRepository,
                    operationManager: operationManager
                ) { [weak self] result in
                    guard let self = self else {
                        return
                    }

                    if case let .success(stash) = result, let stash = stash {
                        self.accountInfoSubscriptionAdapter.subscribe(
                            chainAsset: self.chainAsset,
                            accountId: stash.accountId,
                            handler: self
                        )

                        self.handleStashAccountItem(stash)
                    }

                    self.presenter.didReceiveStash(result: result)
                }
            } else {
                presenter.didReceiveAccountInfo(result: .success(nil))
            }

        } catch {
            presenter.didReceiveStashItem(result: .failure(error))
            presenter.didReceiveAccountInfo(result: .failure(error))
        }
    }
}

extension StakingBondMoreInteractor: AnyProviderAutoCleaning {}

extension StakingBondMoreInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        presenter.didReceiveFee(result: result)
    }
}
