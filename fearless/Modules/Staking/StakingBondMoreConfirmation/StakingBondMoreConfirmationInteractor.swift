import RobinHood
import IrohaCrypto
import BigInt
import SoraKeystore
import FearlessUtils

final class StakingBondMoreConfirmationInteractor: AccountFetching {
    weak var presenter: StakingBondMoreConfirmationOutputProtocol!

    let substrateProviderFactory: SubstrateDataProviderFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol

    private var extrinsicService: ExtrinsicServiceProtocol
    private let feeProxy: ExtrinsicFeeProxyProtocol
    private let runtimeService: RuntimeCodingServiceProtocol
    private let operationManager: OperationManagerProtocol
    private let chain: ChainModel
    private let asset: AssetModel
    private let selectedAccount: MetaAccountModel
    private let accountRepository: AnyDataProviderRepository<MetaAccountModel>
    private let connection: JSONRPCEngine
    private let keystore: KeystoreProtocol

    private var balanceProvider: AnyDataProvider<DecodedAccountInfo>?
    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var stashItemProvider: StreamableProvider<StashItem>?
    private var signingWrapper: SigningWrapperProtocol

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
        selectedAccount: MetaAccountModel,
        signingWrapper: SigningWrapperProtocol,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        connection: JSONRPCEngine,
        keystore: KeystoreProtocol
    ) {
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.substrateProviderFactory = substrateProviderFactory
        self.extrinsicService = extrinsicService
        self.feeProxy = feeProxy
        self.runtimeService = runtimeService
        self.operationManager = operationManager
        self.chain = chain
        self.asset = asset
        self.selectedAccount = selectedAccount
        self.signingWrapper = signingWrapper
        self.accountRepository = accountRepository
        self.connection = connection
        self.keystore = keystore
    }

    func handleStashAccountItem(_ accountItem: ChainAccountResponse) {
        extrinsicService = ExtrinsicService(
            accountId: accountItem.accountId,
            chainFormat: chain.chainFormat,
            cryptoType: accountItem.cryptoType,
            runtimeRegistry: runtimeService,
            engine: connection,
            operationManager: operationManager
        )

        signingWrapper = SigningWrapper(
            keystore: keystore,
            metaId: selectedAccount.metaId,
            accountResponse: accountItem
        )
    }
}

extension StakingBondMoreConfirmationInteractor: StakingBondMoreConfirmationInteractorInputProtocol {
    func setup() {
        if let address = selectedAccount.fetch(for: chain.accountRequest())?.toAddress() {
            stashItemProvider = subscribeStashItemProvider(for: address)
        }

        if let priceId = asset.priceId {
            priceProvider = subscribeToPrice(for: priceId)
        }

        feeProxy.delegate = self
    }

    func estimateFee(for amount: Decimal) {
        guard let amountValue = amount.toSubstrateAmount(
            precision: Int16(asset.precision)
        ) else {
            presenter.didReceiveFee(result: .failure(CommonError.undefined))
            return
        }

        let bondExtra = callFactory.bondExtra(amount: amountValue)

        let idetifier = bondExtra.callName + amountValue.description

        feeProxy.estimateFee(using: extrinsicService, reuseIdentifier: idetifier) { builder in
            try builder.adding(call: bondExtra)
        }
    }

    func submit(for amount: Decimal) {
        guard let amountValue = amount.toSubstrateAmount(precision: Int16(asset.precision)) else {
            presenter.didSubmitBonding(result: .failure(CommonError.undefined))
            return
        }

        let bondExtra = callFactory.bondExtra(amount: amountValue)

        extrinsicService.submit(
            { builder in
                try builder.adding(call: bondExtra)
            },
            signer: signingWrapper,
            runningIn: .main,
            completion: { [weak self] result in
                self?.presenter.didSubmitBonding(result: result)
            }
        )
    }
}

extension StakingBondMoreConfirmationInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        presenter.didReceivePriceData(result: result)
    }
}

extension StakingBondMoreConfirmationInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAccountInfo(result: Result<AccountInfo?, Error>, accountId _: AccountId, chainId _: ChainModel.Id) {
        presenter.didReceiveAccountInfo(result: result)
    }
}

extension StakingBondMoreConfirmationInteractor: StakingLocalStorageSubscriber, StakingLocalSubscriptionHandler {
    func handleStashItem(result: Result<StashItem?, Error>, for _: AccountAddress) {
        do {
            let maybeStashItem = try result.get()

            clear(dataProvider: &balanceProvider)

            presenter.didReceiveStashItem(result: result)

            if let stashItem = maybeStashItem {
                let addressFactory = SS58AddressFactory()

                if let accountId = try? addressFactory.accountId(
                    fromAddress: stashItem.stash,
                    type: chain.addressPrefix
                ) {
                    balanceProvider = subscribeToAccountInfoProvider(for: accountId, chainId: chain.chainId)
                }

                fetchChainAccount(
                    chain: chain,
                    address: stashItem.stash,
                    from: accountRepository,
                    operationManager: operationManager
                ) { [weak self] result in
                    if case let .success(stash) = result, let stash = stash {
                        self?.handleStashAccountItem(stash)
                    }

                    self?.presenter.didReceiveStash(result: result)
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

extension StakingBondMoreConfirmationInteractor: AnyProviderAutoCleaning {}

extension StakingBondMoreConfirmationInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        presenter.didReceiveFee(result: result)
    }
}
