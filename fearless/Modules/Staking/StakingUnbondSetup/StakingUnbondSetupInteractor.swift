import SoraKeystore
import RobinHood
import BigInt
import FearlessUtils

final class StakingUnbondSetupInteractor: RuntimeConstantFetching, AccountFetching {
    weak var presenter: StakingUnbondSetupInteractorOutputProtocol!

    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol

    let singleValueProviderFactory: SingleValueProviderFactoryProtocol
    let substrateProviderFactory: SubstrateDataProviderFactoryProtocol
    let settings: SettingsManagerProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    let operationManager: OperationManagerProtocol
    let extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol
    let selectedMetaAccount: MetaAccountModel
    let chain: ChainModel
    let asset: AssetModel

    private var stashItemProvider: StreamableProvider<StashItem>?
    private var ledgerProvider: AnyDataProvider<DecodedLedgerInfo>?
    private var accountInfoProvider: AnyDataProvider<DecodedAccountInfo>?
    private var priceProvider: AnySingleValueProvider<PriceData>?

    private var extrinsicService: ExtrinsicServiceProtocol?

    private lazy var callFactory = SubstrateCallFactory()

    init(
        asset: AssetModel,
        chain: ChainModel,
        selectedMetaAccount: MetaAccountModel,
        singleValueProviderFactory: SingleValueProviderFactoryProtocol,
        substrateProviderFactory: SubstrateDataProviderFactoryProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        settings: SettingsManagerProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        operationManager: OperationManagerProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    ) {
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.singleValueProviderFactory = singleValueProviderFactory
        self.substrateProviderFactory = substrateProviderFactory
        self.extrinsicService = extrinsicService
        self.feeProxy = feeProxy
        self.selectedMetaAccount = selectedMetaAccount
        self.settings = settings
        self.runtimeService = runtimeService
        self.operationManager = operationManager
        self.asset = asset
        self.chain = chain
    }
}

extension StakingUnbondSetupInteractor: StakingUnbondSetupInteractorInputProtocol {
    func setup() {
        if let address = selectedMetaAccount.fetch(for: chain.accountRequest())?.toAddress() {
            stashItemProvider = subscribeStashItemProvider(for: address)
        }

        if let priceId = asset.priceId {
            priceProvider = subscribeToPrice(for: priceId)
        }

        fetchConstant(
            for: .lockUpPeriod,
            runtimeCodingService: runtimeService,
            operationManager: operationManager
        ) { [weak self] (result: Result<UInt32, Error>) in
            self?.presenter.didReceiveBondingDuration(result: result)
        }

        fetchConstant(
            for: .existentialDeposit,
            runtimeCodingService: runtimeService,
            operationManager: operationManager
        ) { [weak self] (result: Result<BigUInt, Error>) in
            self?.presenter.didReceiveExistentialDeposit(result: result)
        }

        feeProxy.delegate = self

        estimateFee()
    }

    func estimateFee() {
        guard let extrinsicService = extrinsicService,
              let amount = StakingConstants.maxAmount.toSubstrateAmount(
                  precision: Int16(asset.precision)
              ) else {
            return
        }

        let unbondCall = callFactory.unbond(amount: amount)
        let setPayeeCall = callFactory.setPayee(for: .stash)
        let chillCall = callFactory.chill()

        feeProxy.estimateFee(using: extrinsicService, reuseIdentifier: unbondCall.callName) { builder in
            try builder.adding(call: chillCall).adding(call: unbondCall).adding(call: setPayeeCall)
        }
    }
}

extension StakingUnbondSetupInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {
        presenter.didReceiveAccountInfo(result: result)
    }
}

extension StakingUnbondSetupInteractor: StakingLocalStorageSubscriber, StakingLocalSubscriptionHandler, AnyProviderAutoCleaning {
    func handleStashItem(result: Result<StashItem?, Error>, for _: AccountAddress) {
        do {
            let maybeStashItem = try result.get()

            clear(dataProvider: &accountInfoProvider)
            clear(dataProvider: &ledgerProvider)

            presenter.didReceiveStashItem(result: result)

            if let stashItem = maybeStashItem {
                if let accountId = selectedMetaAccount.fetch(for: chain.accountRequest())?.accountId {
                    ledgerProvider = subscribeLedgerInfo(for: accountId, chainId: chain.chainId)
                }

                if let accountId = selectedMetaAccount.fetch(for: chain.accountRequest())?.accountId {
                    accountInfoProvider = subscribeToAccountInfoProvider(for: accountId, chainId: chain.chainId)
                }

                // TODO: Restore logic if needed
//                fetchAccount(
//                    for: stashItem.controller,
//                    from: accountRepository,
//                    operationManager: operationManager
//                ) { [weak self] result in
//                    if case let .success(maybeController) = result, let controller = maybeController {
//                        self?.handleController(accountItem: controller)
//                    }
//
//                    self?.presenter.didReceiveController(result: result)
//                }

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

    func handleAccountInfo(result: Result<AccountInfo?, Error>, address _: AccountAddress) {
        presenter.didReceiveAccountInfo(result: result)
    }
}

extension StakingUnbondSetupInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        presenter.didReceivePriceData(result: result)
    }
}

extension StakingUnbondSetupInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        presenter.didReceiveFee(result: result)
    }
}
