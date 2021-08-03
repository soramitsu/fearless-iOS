import RobinHood
import IrohaCrypto
import BigInt
import SoraKeystore

final class StakingBondMoreConfirmationInteractor: AccountFetching {
    weak var presenter: StakingBondMoreConfirmationOutputProtocol!

    let singleValueProviderFactory: SingleValueProviderFactoryProtocol
    let substrateProviderFactory: SubstrateDataProviderFactoryProtocol

    private let settings: SettingsManagerProtocol
    private let accountRepository: AnyDataProviderRepository<AccountItem>
    private let extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol
    private let feeProxy: ExtrinsicFeeProxyProtocol
    private let runtimeService: RuntimeCodingServiceProtocol
    private let operationManager: OperationManagerProtocol
    private let chain: Chain
    private let assetId: WalletAssetId

    private var balanceProvider: AnyDataProvider<DecodedAccountInfo>?
    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var stashItemProvider: StreamableProvider<StashItem>?
    private var extrinsicService: ExtrinsicServiceProtocol?
    private var signingWrapper: SigningWrapperProtocol?

    private lazy var callFactory = SubstrateCallFactory()

    init(
        settings: SettingsManagerProtocol,
        singleValueProviderFactory: SingleValueProviderFactoryProtocol,
        substrateProviderFactory: SubstrateDataProviderFactoryProtocol,
        accountRepository: AnyDataProviderRepository<AccountItem>,
        extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        operationManager: OperationManagerProtocol,
        chain: Chain,
        assetId: WalletAssetId
    ) {
        self.settings = settings
        self.singleValueProviderFactory = singleValueProviderFactory
        self.substrateProviderFactory = substrateProviderFactory
        self.accountRepository = accountRepository
        self.extrinsicServiceFactory = extrinsicServiceFactory
        self.feeProxy = feeProxy
        self.runtimeService = runtimeService
        self.operationManager = operationManager
        self.chain = chain
        self.assetId = assetId
    }

    func handleStashAccountItem(_ accountItem: AccountItem) {
        extrinsicService = extrinsicServiceFactory.createService(accountItem: accountItem)
        signingWrapper = extrinsicServiceFactory.createSigningWrapper(
            accountItem: accountItem,
            connectionItem: settings.selectedConnection
        )
    }
}

extension StakingBondMoreConfirmationInteractor: StakingBondMoreConfirmationInteractorInputProtocol {
    func setup() {
        if let address = settings.selectedAccount?.address {
            stashItemProvider = subscribeToStashItemProvider(for: address)
        }

        priceProvider = subscribeToPriceProvider(for: assetId)

        feeProxy.delegate = self
    }

    func estimateFee(for amount: Decimal) {
        guard let extrinsicService = extrinsicService,
              let amountValue = amount.toSubstrateAmount(
                  precision: chain.addressType.precision
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
        guard
            let extrinsicService = extrinsicService,
            let signingWrapper = signingWrapper,
            let amountValue = amount.toSubstrateAmount(precision: chain.addressType.precision) else {
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

extension StakingBondMoreConfirmationInteractor: SingleValueProviderSubscriber, SingleValueSubscriptionHandler,
    SubstrateProviderSubscriber, SubstrateProviderSubscriptionHandler,
    AnyProviderAutoCleaning {
    func handleStashItem(result: Result<StashItem?, Error>) {
        do {
            let maybeStashItem = try result.get()

            clear(dataProvider: &balanceProvider)

            presenter.didReceiveStashItem(result: result)

            if let stashItem = maybeStashItem {
                balanceProvider = subscribeToAccountInfoProvider(
                    for: stashItem.stash,
                    runtimeService: runtimeService
                )

                fetchAccount(
                    for: stashItem.stash,
                    from: accountRepository,
                    operationManager: operationManager
                ) { [weak self] result in
                    if case let .success(maybeStash) = result, let stash = maybeStash {
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

    func handleAccountInfo(result: Result<AccountInfo?, Error>, address _: AccountAddress) {
        presenter.didReceiveAccountInfo(result: result)
    }

    func handlePrice(result: Result<PriceData?, Error>, for _: WalletAssetId) {
        presenter.didReceivePriceData(result: result)
    }
}

extension StakingBondMoreConfirmationInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        presenter.didReceiveFee(result: result)
    }
}
