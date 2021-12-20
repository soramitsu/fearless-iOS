import RobinHood
import IrohaCrypto
import BigInt
import SoraKeystore

final class StakingBondMoreInteractor: AccountFetching {
    weak var presenter: StakingBondMoreInteractorOutputProtocol!

    let substrateProviderFactory: SubstrateDataProviderFactoryProtocol

    private let settings: SettingsManagerProtocol
    private let extrinsicService: ExtrinsicServiceProtocol
    private let feeProxy: ExtrinsicFeeProxyProtocol
    private let runtimeService: RuntimeCodingServiceProtocol
    private let operationManager: OperationManagerProtocol
    private let chain: ChainModel
    private let asset: AssetModel
    private let selectedAccount: MetaAccountModel
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol

    private var balanceProvider: AnyDataProvider<DecodedAccountInfo>?
    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var stashItemProvider: StreamableProvider<StashItem>?

    private lazy var callFactory = SubstrateCallFactory()

    init(
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        substrateProviderFactory: SubstrateDataProviderFactoryProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        operationManager: OperationManagerProtocol,
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel
    ) {
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.substrateProviderFactory = substrateProviderFactory
        self.extrinsicService = extrinsicService
        self.feeProxy = feeProxy
        self.runtimeService = runtimeService
        self.operationManager = operationManager
        self.chain = chain
        self.asset = asset
        self.selectedAccount = selectedAccount
    }

    func handleStashAccountItem(_: AccountItem) {}
}

extension StakingBondMoreInteractor: StakingBondMoreInteractorInputProtocol {
    func setup() {
        if let address = selectedAccount.fetch(for: chain.accountRequest())?.toAddress() {
            stashItemProvider = subscribeStashItemProvider(for: address)
        }

        if let priceId = asset.priceId {
            priceProvider = subscribeToPrice(for: priceId)
        }

        feeProxy.delegate = self

        estimateFee()
    }

    func estimateFee() {
        guard let amount = StakingConstants.maxAmount.toSubstrateAmount(
            precision: Int16(asset.precision)
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

extension StakingBondMoreInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAccountInfo(result: Result<AccountInfo?, Error>, accountId _: AccountId, chainId _: ChainModel.Id) {
        presenter.didReceiveAccountInfo(result: result)
    }
}

extension StakingBondMoreInteractor: StakingLocalStorageSubscriber, StakingLocalSubscriptionHandler {
    func handleStashItem(result: Result<StashItem?, Error>, for _: AccountAddress) {
        do {
            let maybeStashItem = try result.get()

            clear(dataProvider: &balanceProvider)

            presenter.didReceiveStashItem(result: result)

            if let stashItem = maybeStashItem {
                let addressFactory = SS58AddressFactory()

                if let accountId = try? addressFactory.accountId(fromAddress: stashItem.stash, type: chain.addressPrefix) {
                    balanceProvider = subscribeToAccountInfoProvider(for: accountId, chainId: chain.chainId)
                }

                estimateFee()
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
