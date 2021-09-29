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
    let chain: Chain
    let assetId: WalletAssetId

    private var stashItemProvider: StreamableProvider<StashItem>?
    private var activeEraProvider: AnyDataProvider<DecodedActiveEra>?
    private var ledgerProvider: AnyDataProvider<DecodedLedgerInfo>?
    private var accountInfoProvider: AnyDataProvider<DecodedAccountInfo>?
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
        accountRepository: AnyDataProviderRepository<AccountItem>,
        settings: SettingsManagerProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        operationManager: OperationManagerProtocol
    ) {
        self.singleValueProviderFactory = singleValueProviderFactory
        self.substrateProviderFactory = substrateProviderFactory
        self.extrinsicServiceFactory = extrinsicServiceFactory
        self.feeProxy = feeProxy
        self.accountRepository = accountRepository
        self.settings = settings
        self.runtimeService = runtimeService
        self.operationManager = operationManager
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

        activeEraProvider = subscribeToActiveEraProvider(for: chain, runtimeService: runtimeService)

        feeProxy.delegate = self
    }

    func submit(for amount: Decimal) {
        guard let extrinsicService = extrinsicService,
              let signingWrapper = signingWrapper,
              let amountValue = amount.toSubstrateAmount(
                  precision: chain.addressType.precision
              ) else {
            presenter.didSubmitRebonding(result: .failure(CommonError.undefined))
            return
        }

        let rebondCall = callFactory.rebond(amount: amountValue)

        extrinsicService.submit(
            { builder in
                try builder.adding(call: rebondCall)
            },
            signer: signingWrapper,
            runningIn: .main,
            completion: { [weak self] result in
                self?.presenter.didSubmitRebonding(result: result)
            }
        )
    }

    func estimateFee(for amount: Decimal) {
        guard let extrinsicService = extrinsicService,
              let amountValue = amount.toSubstrateAmount(
                  precision: chain.addressType.precision
              ) else {
            presenter.didReceiveFee(result: .failure(CommonError.undefined))
            return
        }

        let rebondCall = callFactory.rebond(amount: amountValue)

        feeProxy.estimateFee(using: extrinsicService, reuseIdentifier: rebondCall.callName) { builder in
            try builder.adding(call: rebondCall)
        }
    }
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

    func handleAccountInfo(result: Result<AccountInfo?, Error>, address _: AccountAddress) {
        presenter.didReceiveAccountInfo(result: result)
    }

    func handleLedgerInfo(result: Result<StakingLedger?, Error>, address _: AccountAddress) {
        presenter.didReceiveStakingLedger(result: result)
    }

    func handlePrice(result: Result<PriceData?, Error>, for _: WalletAssetId) {
        presenter.didReceivePriceData(result: result)
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
