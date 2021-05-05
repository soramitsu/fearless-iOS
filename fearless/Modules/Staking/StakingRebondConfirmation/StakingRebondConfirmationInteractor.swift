import UIKit
import SoraKeystore
import RobinHood
import BigInt
import FearlessUtils
import IrohaCrypto

final class StakingRebondConfirmationInteractor: RuntimeConstantFetching, AccountFetching {
    weak var presenter: StakingRebondConfirmationInteractorOutputProtocol!

    let singleValueProviderFactory: SingleValueProviderFactoryProtocol
    let substrateProviderFactory: SubstrateDataProviderFactoryProtocol
    let settings: SettingsManagerProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    let operationManager: OperationManagerProtocol
    let extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol
    let accountRepository: AnyDataProviderRepository<AccountItem>
    let slashesOperationFactory: SlashesOperationFactoryProtocol
    let engine: JSONRPCEngine
    let chain: Chain
    let assetId: WalletAssetId

    private var stashItemProvider: StreamableProvider<StashItem>?
    private var electionStatusProvider: AnyDataProvider<DecodedElectionStatus>?
    private var activeEraProvider: AnyDataProvider<DecodedActiveEra>?
    private var ledgerProvider: AnyDataProvider<DecodedLedgerInfo>?
    private var accountInfoProvider: AnyDataProvider<DecodedAccountInfo>?
    private var payeeProvider: AnyDataProvider<DecodedPayee>?
    private var priceProvider: AnySingleValueProvider<PriceData>?

    private var extrinsicService: ExtrinsicServiceProtocol?
    private var signingWrapper: SigningWrapperProtocol?

    private lazy var callFactory = SubstrateCallFactory()

    init(
        assetId: WalletAssetId,
        chain: Chain,
        singleValueProviderFactory: SingleValueProviderFactoryProtocol,
        substrateProviderFactory: SubstrateDataProviderFactoryProtocol,
        extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        slashesOperationFactory: SlashesOperationFactoryProtocol,
        accountRepository: AnyDataProviderRepository<AccountItem>,
        settings: SettingsManagerProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        engine: JSONRPCEngine,
        operationManager: OperationManagerProtocol
    ) {
        self.singleValueProviderFactory = singleValueProviderFactory
        self.substrateProviderFactory = substrateProviderFactory
        self.extrinsicServiceFactory = extrinsicServiceFactory
        self.feeProxy = feeProxy
        self.slashesOperationFactory = slashesOperationFactory
        self.accountRepository = accountRepository
        self.settings = settings
        self.runtimeService = runtimeService
        self.operationManager = operationManager
        self.engine = engine
        self.assetId = assetId
        self.chain = chain
    }

    private func handleController(accountItem: AccountItem) {
        extrinsicService = extrinsicServiceFactory.createService(accountItem: accountItem)
        signingWrapper = extrinsicServiceFactory.createSigningWrapper(
            accountItem: accountItem,
            connectionItem: settings.selectedConnection
        )
    }
}

extension StakingRebondConfirmationInteractor: StakingRebondConfirmationInteractorInputProtocol {
    func setup() {
        if let address = settings.selectedAccount?.address {
            stashItemProvider = subscribeToStashItemProvider(for: address)
        }

        priceProvider = subscribeToPriceProvider(for: assetId)
        electionStatusProvider = subscribeToElectionStatusProvider(
            chain: chain,
            runtimeService: runtimeService
        )

        activeEraProvider = subscribeToActiveEraProvider(for: chain, runtimeService: runtimeService)

        feeProxy.delegate = self
    }

    func submit(for _: Decimal) {}

    func estimateFee(for _: Decimal) {}
}

extension StakingRebondConfirmationInteractor: SingleValueProviderSubscriber, SingleValueSubscriptionHandler,
    SubstrateProviderSubscriber, SubstrateProviderSubscriptionHandler,
    AnyProviderAutoCleaning {
    func handleStashItem(result: Result<StashItem?, Error>) {
        do {
            let maybeStashItem = try result.get()

            clear(dataProvider: &accountInfoProvider)
            clear(dataProvider: &ledgerProvider)

            presenter.didReceiveStashItem(result: result)

            if let stashItem = maybeStashItem {
                ledgerProvider = subscribeToLedgerInfoProvider(
                    for: stashItem.controller,
                    runtimeService: runtimeService
                )

                accountInfoProvider = subscribeToAccountInfoProvider(
                    for: stashItem.controller,
                    runtimeService: runtimeService
                )

                payeeProvider = subscribeToPayeeProvider(
                    for: stashItem.stash,
                    runtimeService: runtimeService
                )

                fetchAccount(
                    for: stashItem.controller,
                    from: accountRepository,
                    operationManager: operationManager
                ) { [weak self] result in
                    if case let .success(maybeController) = result, let controller = maybeController {
                        self?.handleController(accountItem: controller)
                    }

                    self?.presenter.didReceiveController(result: result)
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

    func handleAccountInfo(result: Result<DyAccountInfo?, Error>, address _: AccountAddress) {
        presenter.didReceiveAccountInfo(result: result)
    }

    func handleLedgerInfo(result: Result<DyStakingLedger?, Error>, address _: AccountAddress) {
        presenter.didReceiveStakingLedger(result: result)
    }

    func handlePrice(result: Result<PriceData?, Error>, for _: WalletAssetId) {
        presenter.didReceivePriceData(result: result)
    }

    func handleElectionStatus(result: Result<ElectionStatus?, Error>, chain _: Chain) {
        presenter.didReceiveElectionStatus(result: result)
    }

    func handleActiveEra(result: Result<ActiveEraInfo?, Error>, chain _: Chain) {
        presenter.didReceiveActiveEra(result: result)
    }
}

extension StakingRebondConfirmationInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        presenter.didReceiveFee(result: result)
    }
}
