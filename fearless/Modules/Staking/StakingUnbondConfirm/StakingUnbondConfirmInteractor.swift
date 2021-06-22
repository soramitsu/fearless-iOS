import Foundation
import SoraKeystore
import RobinHood
import BigInt
import FearlessUtils

final class StakingUnbondConfirmInteractor: RuntimeConstantFetching, AccountFetching {
    weak var presenter: StakingUnbondConfirmInteractorOutputProtocol!

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
    private var minBondedProvider: AnyDataProvider<DecodedMinNominatorBond>?
    private var ledgerProvider: AnyDataProvider<DecodedLedgerInfo>?
    private var accountInfoProvider: AnyDataProvider<DecodedAccountInfo>?
    private var nominationProvider: AnyDataProvider<DecodedNomination>?
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

    private func setupExtrinsicBuiler(
        _ builder: ExtrinsicBuilderProtocol,
        amount: Decimal,
        resettingRewardDestination: Bool,
        chilling: Bool
    ) throws -> ExtrinsicBuilderProtocol {
        guard let amountValue = amount.toSubstrateAmount(precision: chain.addressType.precision) else {
            throw CommonError.undefined
        }

        var resultBuilder = builder

        if chilling {
            resultBuilder = try builder.adding(call: callFactory.chill())
        }

        resultBuilder = try resultBuilder.adding(call: callFactory.unbond(amount: amountValue))

        if resettingRewardDestination {
            resultBuilder = try resultBuilder.adding(call: callFactory.setPayee(for: .stash))
        }

        return resultBuilder
    }
}

extension StakingUnbondConfirmInteractor: StakingUnbondConfirmInteractorInputProtocol {
    func setup() {
        if let address = settings.selectedAccount?.address {
            stashItemProvider = subscribeToStashItemProvider(for: address)
        }

        priceProvider = subscribeToPriceProvider(for: assetId)
        electionStatusProvider = subscribeToElectionStatusProvider(
            chain: chain,
            runtimeService: runtimeService
        )

        minBondedProvider = subscribeToMinNominatorBondProvider(chain: chain, runtimeService: runtimeService)

        fetchConstant(
            for: .existentialDeposit,
            runtimeCodingService: runtimeService,
            operationManager: operationManager
        ) { [weak self] (result: Result<BigUInt, Error>) in
            self?.presenter.didReceiveExistentialDeposit(result: result)
        }

        feeProxy.delegate = self
    }

    func estimateFee(for amount: Decimal, resettingRewardDestination: Bool, chilling: Bool) {
        guard let extrinsicService = extrinsicService else {
            presenter.didReceiveFee(result: .failure(CommonError.undefined))
            return
        }

        let reuseIdetifier = amount.description + resettingRewardDestination.description

        feeProxy.estimateFee(
            using: extrinsicService,
            reuseIdentifier: reuseIdetifier
        ) { [weak self] builder in
            guard let strongSelf = self else {
                throw CommonError.undefined
            }

            return try strongSelf.setupExtrinsicBuiler(
                builder,
                amount: amount,
                resettingRewardDestination: resettingRewardDestination,
                chilling: chilling
            )
        }
    }

    func submit(for amount: Decimal, resettingRewardDestination: Bool, chilling: Bool) {
        guard
            let extrinsicService = extrinsicService,
            let signingWrapper = signingWrapper else {
            presenter.didSubmitUnbonding(result: .failure(CommonError.undefined))
            return
        }

        let builderClosure: ExtrinsicBuilderClosure = { [weak self] builder in
            guard let strongSelf = self else {
                throw CommonError.undefined
            }

            return try strongSelf.setupExtrinsicBuiler(
                builder,
                amount: amount,
                resettingRewardDestination: resettingRewardDestination,
                chilling: chilling
            )
        }

        extrinsicService.submit(
            builderClosure,
            signer: signingWrapper,
            runningIn: .main,
            completion: { [weak self] result in
                self?.presenter.didSubmitUnbonding(result: result)
            }
        )
    }
}

extension StakingUnbondConfirmInteractor: SingleValueProviderSubscriber, SingleValueSubscriptionHandler,
    SubstrateProviderSubscriber, SubstrateProviderSubscriptionHandler,
    AnyProviderAutoCleaning {
    func handleStashItem(result: Result<StashItem?, Error>) {
        do {
            let maybeStashItem = try result.get()

            clear(dataProvider: &accountInfoProvider)
            clear(dataProvider: &ledgerProvider)
            clear(dataProvider: &payeeProvider)
            clear(dataProvider: &nominationProvider)

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

                nominationProvider = subscribeToNominationProvider(
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
                presenter.didReceiveNomination(result: .success(nil))
            }

        } catch {
            presenter.didReceiveStashItem(result: .failure(error))
            presenter.didReceiveAccountInfo(result: .failure(error))
            presenter.didReceiveStakingLedger(result: .failure(error))
            presenter.didReceivePayee(result: .failure(error))
            presenter.didReceiveNomination(result: .failure(error))
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

    func handleElectionStatus(result: Result<ElectionStatus?, Error>, chain _: Chain) {
        presenter.didReceiveElectionStatus(result: result)
    }

    func handleMinNominatorBond(result: Result<BigUInt?, Error>, chain _: Chain) {
        presenter.didReceiveMinBonded(result: result)
    }

    func handleNomination(result: Result<Nomination?, Error>, address _: AccountAddress) {
        presenter.didReceiveNomination(result: result)
    }
}

extension StakingUnbondConfirmInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        presenter.didReceiveFee(result: result)
    }
}
