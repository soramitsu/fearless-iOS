import UIKit
import SoraKeystore
import RobinHood
import BigInt
import FearlessUtils

final class StakingUnbondSetupInteractor: RuntimeConstantFetching, AccountFetching {
    weak var presenter: StakingUnbondSetupInteractorOutputProtocol!

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
    private var electionStatusProvider: AnyDataProvider<DecodedElectionStatus>?
    private var ledgerProvider: AnyDataProvider<DecodedLedgerInfo>?
    private var accountInfoProvider: AnyDataProvider<DecodedAccountInfo>?
    private var priceProvider: AnySingleValueProvider<PriceData>?

    private var extrinisicService: ExtrinsicServiceProtocol?

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
        extrinisicService = extrinsicServiceFactory.createService(accountItem: accountItem)

        estimateFee()
    }
}

extension StakingUnbondSetupInteractor: StakingUnbondSetupInteractorInputProtocol {
    func setup() {
        if let address = settings.selectedAccount?.address {
            stashItemProvider = subscribeToStashItemProvider(for: address)
        }

        priceProvider = subscribeToPriceProvider(for: assetId)
        electionStatusProvider = subscribeToElectionStatusProvider(chain: chain, runtimeService: runtimeService)

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
    }

    func estimateFee() {
        guard let extrinsicService = extrinisicService,
              let amount = StakingConstants.maxAmount.toSubstrateAmount(
                  precision: chain.addressType.precision
              ) else {
            return
        }

        let unbondCall = callFactory.unbond(amount: amount)
        let setPayeeCall = callFactory.setPayee(for: .stash)

        feeProxy.estimateFee(using: extrinsicService, reuseIdentifier: unbondCall.callName) { builder in
            try builder.adding(call: unbondCall).adding(call: setPayeeCall)
        }
    }
}

extension StakingUnbondSetupInteractor: SingleValueProviderSubscriber, SingleValueSubscriptionHandler,
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
}

extension StakingUnbondSetupInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        presenter.didReceiveFee(result: result)
    }
}
