import RobinHood
import SoraKeystore
import FearlessUtils
import IrohaCrypto

final class StakingRebondSetupInteractor: RuntimeConstantFetching, AccountFetching {
    weak var presenter: StakingRebondSetupInteractorOutputProtocol!

    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    let operationManager: OperationManagerProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol
    let chain: ChainModel
    let asset: AssetModel
    let selectedAccount: MetaAccountModel
    let connection: JSONRPCEngine

    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var stashItemProvider: StreamableProvider<StashItem>?
    private var accountInfoProvider: AnyDataProvider<DecodedAccountInfo>?
    private var ledgerProvider: AnyDataProvider<DecodedLedgerInfo>?
    private var extrinsicService: ExtrinsicServiceProtocol?
    private var activeEraProvider: AnyDataProvider<DecodedActiveEra>?

    private lazy var callFactory = SubstrateCallFactory()

    init(
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol,
        runtimeCodingService: RuntimeCodingServiceProtocol,
        operationManager: OperationManagerProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel,
        connection: JSONRPCEngine,
        extrinsicService: ExtrinsicServiceProtocol
    ) {
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        runtimeService = runtimeCodingService
        self.operationManager = operationManager
        self.feeProxy = feeProxy
        self.chain = chain
        self.asset = asset
        self.selectedAccount = selectedAccount
        self.connection = connection
        self.extrinsicService = extrinsicService
    }

    private func handleController(accountItem: ChainAccountResponse) {
        extrinsicService = ExtrinsicService(
            accountId: accountItem.accountId,
            chainFormat: accountItem.chainFormat(),
            cryptoType: accountItem.cryptoType,
            runtimeRegistry: runtimeService,
            engine: connection,
            operationManager: operationManager
        )

        estimateFee()
    }
}

extension StakingRebondSetupInteractor: StakingRebondSetupInteractorInputProtocol {
    func setup() {
        if let address = selectedAccount.fetch(for: chain.accountRequest())?.toAddress() {
            stashItemProvider = subscribeStashItemProvider(for: address)
        }

        if let priceId = asset.priceId {
            priceProvider = subscribeToPrice(for: priceId)
        }

        activeEraProvider = subscribeActiveEra(for: chain.chainId)

        feeProxy.delegate = self
    }

    func estimateFee() {
        guard let extrinsicService = extrinsicService,
              let amount = StakingConstants.maxAmount.toSubstrateAmount(
                  precision: Int16(asset.precision)
              ) else {
            return
        }

        let rebondCall = callFactory.rebond(amount: amount)

        feeProxy.estimateFee(using: extrinsicService, reuseIdentifier: rebondCall.callName) { builder in
            try builder.adding(call: rebondCall)
        }
    }
}

extension StakingRebondSetupInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        presenter.didReceivePriceData(result: result)
    }
}

extension StakingRebondSetupInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAccountInfo(result: Result<AccountInfo?, Error>, accountId _: AccountId, chainId _: ChainModel.Id) {
        presenter.didReceiveAccountInfo(result: result)
    }
}

extension StakingRebondSetupInteractor: StakingLocalStorageSubscriber, StakingLocalSubscriptionHandler {
    func handleStashItem(result: Result<StashItem?, Error>, for _: AccountAddress) {
        do {
            let maybeStashItem = try result.get()

            clear(dataProvider: &accountInfoProvider)
            clear(dataProvider: &ledgerProvider)

            presenter.didReceiveStashItem(result: result)

            let addressFactory = SS58AddressFactory()

            if let stashItem = maybeStashItem,
               let accountId = try? addressFactory.accountId(fromAddress: stashItem.controller, type: chain.addressPrefix) {
                ledgerProvider = subscribeLedgerInfo(for: accountId, chainId: chain.chainId)

                accountInfoProvider = subscribeToAccountInfoProvider(for: accountId, chainId: chain.chainId)

                // TODO: Check this logic
                if let accountResponse = selectedAccount.fetch(for: chain.accountRequest()) {
                    handleController(accountItem: accountResponse)
//                    self?.presenter.didReceiveController(result: result)
                }
            } else {
                presenter.didReceiveStakingLedger(result: .success(nil))
                presenter.didReceiveAccountInfo(result: .success(nil))
            }

        } catch {
            presenter.didReceiveStashItem(result: .failure(error))
            presenter.didReceiveAccountInfo(result: .failure(error))
            presenter.didReceiveStakingLedger(result: .failure(error))
        }
    }

    func handleLedgerInfo(result: Result<StakingLedger?, Error>, accountId _: AccountId, chainId _: ChainModel.Id) {
        presenter.didReceiveStakingLedger(result: result)
    }

    func handleActiveEra(result: Result<ActiveEraInfo?, Error>, chainId _: ChainModel.Id) {
        presenter.didReceiveActiveEra(result: result)
    }
}

extension StakingRebondSetupInteractor: AnyProviderAutoCleaning, ExtrinsicFeeProxyDelegate {
    // MARK: - ExtrinsicFeeProxyDelegate

    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        presenter.didReceiveFee(result: result)
    }
}
