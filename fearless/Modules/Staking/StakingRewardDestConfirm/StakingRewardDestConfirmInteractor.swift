import UIKit
import RobinHood
import IrohaCrypto
import SoraKeystore

final class StakingRewardDestConfirmInteractor: AccountFetching {
    weak var presenter: StakingRewardDestConfirmInteractorOutputProtocol!

    let settings: SettingsManagerProtocol
    let singleValueProviderFactory: SingleValueProviderFactoryProtocol
    let extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol
    let substrateProviderFactory: SubstrateDataProviderFactoryProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    let operationManager: OperationManagerProtocol
    let accountRepository: AnyDataProviderRepository<AccountItem>
    let feeProxy: ExtrinsicFeeProxyProtocol
    let assetId: WalletAssetId
    let chain: Chain

    private var electionStatusProvider: AnyDataProvider<DecodedElectionStatus>?
    private var stashItemProvider: StreamableProvider<StashItem>?
    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var accountInfoProvider: AnyDataProvider<DecodedAccountInfo>?

    private var extrinsicService: ExtrinsicServiceProtocol?
    private var signingWrapper: SigningWrapperProtocol?

    private lazy var callFactory = SubstrateCallFactory()
    private lazy var addressFactory = SS58AddressFactory()

    init(
        settings: SettingsManagerProtocol,
        singleValueProviderFactory: SingleValueProviderFactoryProtocol,
        extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol,
        substrateProviderFactory: SubstrateDataProviderFactoryProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        operationManager: OperationManagerProtocol,
        accountRepository: AnyDataProviderRepository<AccountItem>,
        feeProxy: ExtrinsicFeeProxyProtocol,
        assetId: WalletAssetId,
        chain: Chain
    ) {
        self.settings = settings
        self.singleValueProviderFactory = singleValueProviderFactory
        self.extrinsicServiceFactory = extrinsicServiceFactory
        self.substrateProviderFactory = substrateProviderFactory
        self.runtimeService = runtimeService
        self.operationManager = operationManager
        self.accountRepository = accountRepository
        self.feeProxy = feeProxy
        self.assetId = assetId
        self.chain = chain
    }

    private func setupExtrinsicService(_ accountItem: AccountItem) {
        extrinsicService = extrinsicServiceFactory.createService(accountItem: accountItem)
        signingWrapper = extrinsicServiceFactory.createSigningWrapper(
            accountItem: accountItem,
            connectionItem: settings.selectedConnection
        )
    }
}

extension StakingRewardDestConfirmInteractor: StakingRewardDestConfirmInteractorInputProtocol {
    func setup() {
        guard let selectedAccountAddress = settings.selectedAccount?.address else {
            return
        }

        stashItemProvider = subscribeToStashItemProvider(for: selectedAccountAddress)

        priceProvider = subscribeToPriceProvider(for: assetId)
        electionStatusProvider = subscribeToElectionStatusProvider(chain: chain, runtimeService: runtimeService)

        feeProxy.delegate = self
    }

    func estimateFee(for rewardDestination: RewardDestination<AccountAddress>, stashItem: StashItem) {
        guard let extrinsicService = extrinsicService else {
            presenter.didReceiveFee(result: .failure(CommonError.undefined))
            return
        }

        do {
            let setPayeeCall = try callFactory.setRewardDestination(rewardDestination, stashItem: stashItem)

            feeProxy.estimateFee(
                using: extrinsicService,
                reuseIdentifier: setPayeeCall.callName
            ) { builder in
                try builder.adding(call: setPayeeCall)
            }
        } catch {
            presenter.didReceiveFee(result: .failure(error))
        }
    }

    func submit(rewardDestination: RewardDestination<AccountAddress>, for stashItem: StashItem) {
        guard let extrinsicService = extrinsicService, let signingWrapper = signingWrapper else {
            presenter.didSubmitRewardDest(result: .failure(CommonError.undefined))
            return
        }

        do {
            let setPayeeCall = try callFactory.setRewardDestination(rewardDestination, stashItem: stashItem)

            extrinsicService.submit(
                { builder in
                    try builder.adding(call: setPayeeCall)
                },
                signer: signingWrapper,
                runningIn: .main
            ) { [weak self] result in
                self?.presenter.didSubmitRewardDest(result: result)
            }
        } catch {
            presenter.didSubmitRewardDest(result: .failure(error))
        }
    }
}

extension StakingRewardDestConfirmInteractor: SubstrateProviderSubscriber,
    SubstrateProviderSubscriptionHandler, SingleValueProviderSubscriber,
    SingleValueSubscriptionHandler, AnyProviderAutoCleaning {
    func handleStashItem(result: Result<StashItem?, Error>) {
        do {
            let stashItem = try result.get()

            clear(dataProvider: &accountInfoProvider)

            if let stashItem = stashItem {
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
                        self?.setupExtrinsicService(controller)
                    }

                    self?.presenter.didReceiveStashItem(result: .success(stashItem))
                    self?.presenter.didReceiveController(result: result)
                }

            } else {
                presenter.didReceiveStashItem(result: .success(nil))
                presenter.didReceiveAccountInfo(result: .success(nil))
                presenter.didReceiveController(result: .success(nil))
            }

        } catch {
            presenter.didReceiveStashItem(result: .failure(error))
            presenter.didReceiveController(result: .success(nil))
            presenter.didReceiveAccountInfo(result: .failure(error))
        }
    }

    func handlePrice(result: Result<PriceData?, Error>, for _: WalletAssetId) {
        presenter.didReceivePriceData(result: result)
    }

    func handleAccountInfo(result: Result<AccountInfo?, Error>, address _: AccountAddress) {
        presenter.didReceiveAccountInfo(result: result)
    }

    func handleElectionStatus(result: Result<ElectionStatus?, Error>, chain _: Chain) {
        presenter.didReceiveElectionStatus(result: result)
    }
}

extension StakingRewardDestConfirmInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        presenter.didReceiveFee(result: result)
    }
}
