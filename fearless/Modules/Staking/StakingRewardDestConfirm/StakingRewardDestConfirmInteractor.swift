import UIKit
import RobinHood
import IrohaCrypto
import SoraKeystore
import SSFUtils

final class StakingRewardDestConfirmInteractor: AccountFetching {
    weak var presenter: StakingRewardDestConfirmInteractorOutputProtocol!

    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let stakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol
    let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol

    var extrinsicService: ExtrinsicServiceProtocol
    let substrateProviderFactory: SubstrateDataProviderFactoryProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    let operationManager: OperationManagerProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol
    let chainAsset: ChainAsset
    var signingWrapper: SigningWrapperProtocol
    let selectedAccount: MetaAccountModel
    let accountRepository: AnyDataProviderRepository<MetaAccountModel>
    let connection: JSONRPCEngine
    let keystore: KeystoreProtocol

    private var stashItemProvider: StreamableProvider<StashItem>?
    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var accountInfoProvider: AnyDataProvider<DecodedAccountInfo>?

    private let callFactory: SubstrateCallFactoryProtocol
    private lazy var addressFactory = SS58AddressFactory()

    init(
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        stakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        substrateProviderFactory: SubstrateDataProviderFactoryProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        operationManager: OperationManagerProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        chainAsset: ChainAsset,
        selectedAccount: MetaAccountModel,
        signingWrapper: SigningWrapperProtocol,
        connection: JSONRPCEngine,
        keystore: KeystoreProtocol,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        callFactory: SubstrateCallFactoryProtocol
    ) {
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.extrinsicService = extrinsicService
        self.substrateProviderFactory = substrateProviderFactory
        self.runtimeService = runtimeService
        self.operationManager = operationManager
        self.feeProxy = feeProxy
        self.chainAsset = chainAsset
        self.selectedAccount = selectedAccount
        self.signingWrapper = signingWrapper
        self.keystore = keystore
        self.connection = connection
        self.accountRepository = accountRepository
        self.callFactory = callFactory
    }

    private func setupExtrinsicService(_ account: ChainAccountResponse) {
        extrinsicService = ExtrinsicService(
            accountId: account.accountId,
            chainFormat: chainAsset.chain.chainFormat,
            cryptoType: account.cryptoType,
            runtimeRegistry: runtimeService,
            engine: connection,
            operationManager: operationManager
        )

        signingWrapper = SigningWrapper(
            keystore: keystore,
            metaId: account.walletId,
            accountResponse: account
        )
    }
}

extension StakingRewardDestConfirmInteractor: StakingRewardDestConfirmInteractorInputProtocol {
    func setup() {
        if let address = selectedAccount.fetch(for: chainAsset.chain.accountRequest())?.toAddress() {
            stashItemProvider = subscribeStashItemProvider(for: address)
        }

        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId)
        }

        feeProxy.delegate = self
    }

    func estimateFee(for rewardDestination: RewardDestination<AccountAddress>, stashItem: StashItem) {
        do {
            let setPayeeCall = try callFactory.setRewardDestination(rewardDestination, stashItem: stashItem)

            feeProxy.estimateFee(
                using: extrinsicService,
                reuseIdentifier: UUID().uuidString
            ) { builder in
                try builder.adding(call: setPayeeCall)
            }
        } catch {
            presenter.didReceiveFee(result: .failure(error))
        }
    }

    func submit(rewardDestination: RewardDestination<AccountAddress>, for stashItem: StashItem) {
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

extension StakingRewardDestConfirmInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        presenter.didReceivePriceData(result: result)
    }
}

extension StakingRewardDestConfirmInteractor: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(result: Result<AccountInfo?, Error>, accountId _: AccountId, chainAsset _: ChainAsset) {
        presenter.didReceiveAccountInfo(result: result)
    }
}

extension StakingRewardDestConfirmInteractor: RelaychainStakingLocalStorageSubscriber, RelaychainStakingLocalSubscriptionHandler {
    func handleStashItem(result: Result<StashItem?, Error>, for _: AccountAddress) {
        do {
            let stashItem = try result.get()

            accountInfoSubscriptionAdapter.reset()

            if let stashItem = stashItem {
                let accountId = try addressFactory.accountId(fromAddress: stashItem.controller, type: chainAsset.chain.addressPrefix)
                accountInfoSubscriptionAdapter.subscribe(chainAsset: chainAsset, accountId: accountId, handler: self)

                fetchChainAccount(
                    chain: chainAsset.chain,
                    address: stashItem.controller,
                    from: accountRepository,
                    operationManager: operationManager
                ) { [weak self] result in
                    if case let .success(maybeController) = result, let controller = maybeController {
                        self?.presenter.didReceiveController(result: result)
                        self?.setupExtrinsicService(controller)
                    }
                }

                presenter.didReceiveStashItem(result: .success(stashItem))

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
}

extension StakingRewardDestConfirmInteractor: AnyProviderAutoCleaning {}

extension StakingRewardDestConfirmInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        presenter.didReceiveFee(result: result)
    }
}
