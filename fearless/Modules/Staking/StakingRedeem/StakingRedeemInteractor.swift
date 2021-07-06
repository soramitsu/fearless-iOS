import UIKit
import SoraKeystore
import RobinHood
import BigInt
import FearlessUtils
import IrohaCrypto

final class StakingRedeemInteractor: RuntimeConstantFetching, AccountFetching {
    weak var presenter: StakingRedeemInteractorOutputProtocol!

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

    private func setupExtrinsicBuiler(
        _ builder: ExtrinsicBuilderProtocol,
        numberOfSlashingSpans: UInt32,
        resettingRewardDestination: Bool
    ) throws -> ExtrinsicBuilderProtocol {
        if resettingRewardDestination {
            return try builder
                .adding(call: callFactory.withdrawUnbonded(for: numberOfSlashingSpans))
                .adding(call: callFactory.setPayee(for: .stash))
        } else {
            return try builder
                .adding(call: callFactory.withdrawUnbonded(for: numberOfSlashingSpans))
        }
    }

    private func fetchSlashingSpansForStash(
        _ stash: AccountAddress,
        completionClosure: @escaping (Result<SlashingSpans?, Error>) -> Void
    ) {
        let wrapper = slashesOperationFactory.createSlashingSpansOperationForStash(
            stash,
            engine: engine,
            runtimeService: runtimeService
        )

        wrapper.targetOperation.completionBlock = {
            DispatchQueue.main.async {
                if let result = wrapper.targetOperation.result {
                    completionClosure(result)
                } else {
                    completionClosure(.failure(BaseOperationError.unexpectedDependentResult))
                }
            }
        }

        operationManager.enqueue(
            operations: wrapper.allOperations,
            in: .transient
        )
    }

    private func estimateFee(with numberOfSlasingSpans: UInt32, resettingRewardDestination: Bool) {
        guard let extrinsicService = extrinsicService else {
            presenter.didReceiveFee(result: .failure(CommonError.undefined))
            return
        }

        let reuseIdetifier = resettingRewardDestination.description

        feeProxy.estimateFee(
            using: extrinsicService,
            reuseIdentifier: reuseIdetifier
        ) { [weak self] builder in
            guard let strongSelf = self else {
                throw CommonError.undefined
            }

            return try strongSelf.setupExtrinsicBuiler(
                builder,
                numberOfSlashingSpans: numberOfSlasingSpans,
                resettingRewardDestination: resettingRewardDestination
            )
        }
    }

    private func submit(with numberOfSlasingSpans: UInt32, resettingRewardDestination: Bool) {
        guard
            let extrinsicService = extrinsicService,
            let signingWrapper = signingWrapper else {
            presenter.didSubmitRedeeming(result: .failure(CommonError.undefined))
            return
        }

        extrinsicService.submit(
            { [weak self] builder in
                guard let strongSelf = self else {
                    throw CommonError.undefined
                }

                return try strongSelf.setupExtrinsicBuiler(
                    builder,
                    numberOfSlashingSpans: numberOfSlasingSpans,
                    resettingRewardDestination: resettingRewardDestination
                )
            },
            signer: signingWrapper,
            runningIn: .main,
            completion: { [weak self] result in
                self?.presenter.didSubmitRedeeming(result: result)
            }
        )
    }
}

extension StakingRedeemInteractor: StakingRedeemInteractorInputProtocol {
    func setup() {
        if let address = settings.selectedAccount?.address {
            stashItemProvider = subscribeToStashItemProvider(for: address)
        }

        priceProvider = subscribeToPriceProvider(for: assetId)

        activeEraProvider = subscribeToActiveEraProvider(for: chain, runtimeService: runtimeService)

        fetchConstant(
            for: .existentialDeposit,
            runtimeCodingService: runtimeService,
            operationManager: operationManager
        ) { [weak self] (result: Result<BigUInt, Error>) in
            self?.presenter.didReceiveExistentialDeposit(result: result)
        }

        feeProxy.delegate = self
    }

    func estimateFeeForStash(_ stashAddress: AccountAddress, resettingRewardDestination: Bool) {
        fetchSlashingSpansForStash(stashAddress) { [weak self] result in
            switch result {
            case let .success(slashingSpans):
                let numberOfSlashes = slashingSpans.map { $0.prior.count + 1 } ?? 0
                self?.estimateFee(
                    with: UInt32(numberOfSlashes),
                    resettingRewardDestination: resettingRewardDestination
                )
            case let .failure(error):
                self?.presenter.didSubmitRedeeming(result: .failure(error))
            }
        }
    }

    func submitForStash(_ stashAddress: AccountAddress, resettingRewardDestination: Bool) {
        fetchSlashingSpansForStash(stashAddress) { [weak self] result in
            switch result {
            case let .success(slashingSpans):
                let numberOfSlashes = slashingSpans.map { $0.prior.count + 1 } ?? 0
                self?.submit(
                    with: UInt32(numberOfSlashes),
                    resettingRewardDestination: resettingRewardDestination
                )
            case let .failure(error):
                self?.presenter.didSubmitRedeeming(result: .failure(error))
            }
        }
    }
}

extension StakingRedeemInteractor: SingleValueProviderSubscriber, SingleValueSubscriptionHandler,
    SubstrateProviderSubscriber, SubstrateProviderSubscriptionHandler,
    AnyProviderAutoCleaning {
    func handleStashItem(result: Result<StashItem?, Error>) {
        do {
            let maybeStashItem = try result.get()

            clear(dataProvider: &accountInfoProvider)
            clear(dataProvider: &ledgerProvider)
            clear(dataProvider: &payeeProvider)

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
                presenter.didReceivePayee(result: .success(nil))
            }

        } catch {
            presenter.didReceiveStashItem(result: .failure(error))
            presenter.didReceiveAccountInfo(result: .failure(error))
            presenter.didReceiveStakingLedger(result: .failure(error))
            presenter.didReceivePayee(result: .failure(error))
        }
    }

    func handleAccountInfo(result: Result<AccountInfo?, Error>, address _: AccountAddress) {
        presenter.didReceiveAccountInfo(result: result)
    }

    func handleLedgerInfo(result: Result<StakingLedger?, Error>, address _: AccountAddress) {
        presenter.didReceiveStakingLedger(result: result)
    }

    func handlePayee(result: Result<RewardDestinationArg?, Error>, address _: AccountAddress) {
        presenter.didReceivePayee(result: result)
    }

    func handlePrice(result: Result<PriceData?, Error>, for _: WalletAssetId) {
        presenter.didReceivePriceData(result: result)
    }

    func handleActiveEra(result: Result<ActiveEraInfo?, Error>, chain _: Chain) {
        presenter.didReceiveActiveEra(result: result)
    }
}

extension StakingRedeemInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        presenter.didReceiveFee(result: result)
    }
}
