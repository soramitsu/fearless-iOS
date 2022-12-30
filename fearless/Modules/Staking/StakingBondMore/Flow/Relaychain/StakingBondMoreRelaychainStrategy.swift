import Foundation
import RobinHood
import FearlessUtils

protocol StakingBondMoreRelaychainStrategyOutput: AnyObject {
    func didReceiveStash(result: Result<ChainAccountResponse?, Error>)
    func didReceiveStashItem(result: Result<StashItem?, Error>)
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>)
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>)

    func extrinsicServiceUpdated()
}

final class StakingBondMoreRelaychainStrategy: AccountFetching {
    private var stashItemProvider: StreamableProvider<StashItem>?
    private var balanceProvider: AnyDataProvider<DecodedAccountInfo>?

    let stakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol
    let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol

    private weak var output: StakingBondMoreRelaychainStrategyOutput?
    private let chainAsset: ChainAsset
    private let wallet: MetaAccountModel
    private let accountRepository: AnyDataProviderRepository<MetaAccountModel>
    private let connection: JSONRPCEngine
    private var extrinsicService: ExtrinsicServiceProtocol
    private let feeProxy: ExtrinsicFeeProxyProtocol
    private let runtimeService: RuntimeCodingServiceProtocol
    private let operationManager: OperationManagerProtocol

    private lazy var callFactory = SubstrateCallFactory()

    init(
        stakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        output: StakingBondMoreRelaychainStrategyOutput?,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        connection: JSONRPCEngine,
        extrinsicService: ExtrinsicServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        operationManager: OperationManagerProtocol
    ) {
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.output = output
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.accountRepository = accountRepository
        self.connection = connection
        self.extrinsicService = extrinsicService
        self.feeProxy = feeProxy
        self.runtimeService = runtimeService
        self.operationManager = operationManager

        self.feeProxy.delegate = self
    }
}

extension StakingBondMoreRelaychainStrategy: StakingBondMoreStrategy {
    func estimateFee(builderClosure: ExtrinsicBuilderClosure?, reuseIdentifier: String?) {
        guard let reuseIdentifier = reuseIdentifier, let builderClosure = builderClosure else {
            return
        }

        feeProxy.estimateFee(using: extrinsicService, reuseIdentifier: reuseIdentifier, setupBy: builderClosure)
    }

    func setup() {
        if let address = wallet.fetch(for: chainAsset.chain.accountRequest())?.toAddress() {
            stashItemProvider = subscribeStashItemProvider(for: address)
        }
    }
}

extension StakingBondMoreRelaychainStrategy: RelaychainStakingLocalStorageSubscriber, RelaychainStakingLocalSubscriptionHandler {
    func handleStashAccountItem(_ account: ChainAccountResponse) {
        extrinsicService = ExtrinsicService(
            accountId: account.accountId,
            chainFormat: chainAsset.chain.chainFormat,
            cryptoType: account.cryptoType,
            runtimeRegistry: runtimeService,
            engine: connection,
            operationManager: operationManager
        )

        output?.extrinsicServiceUpdated()
    }

    func handleStashItem(result: Result<StashItem?, Error>, for _: AccountAddress) {
        do {
            let maybeStashItem = try result.get()

            accountInfoSubscriptionAdapter.reset()

            output?.didReceiveStashItem(result: result)

            if let stashItem = maybeStashItem {
                fetchChainAccount(
                    chain: chainAsset.chain,
                    address: stashItem.stash,
                    from: accountRepository,
                    operationManager: operationManager
                ) { [weak self] result in
                    guard let self = self else {
                        return
                    }

                    if case let .success(stash) = result, let stash = stash {
                        self.accountInfoSubscriptionAdapter.subscribe(
                            chainAsset: self.chainAsset,
                            accountId: stash.accountId,
                            handler: self
                        )

                        self.handleStashAccountItem(stash)
                    }

                    self.output?.didReceiveStash(result: result)
                }
            } else {
                output?.didReceiveAccountInfo(result: .success(nil))
            }

        } catch {
            output?.didReceiveStashItem(result: .failure(error))
            output?.didReceiveAccountInfo(result: .failure(error))
        }
    }
}

extension StakingBondMoreRelaychainStrategy: AnyProviderAutoCleaning {}

extension StakingBondMoreRelaychainStrategy: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        output?.didReceiveFee(result: result)
    }
}

extension StakingBondMoreRelaychainStrategy: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(result: Result<AccountInfo?, Error>, accountId _: AccountId, chainAsset _: ChainAsset) {
        output?.didReceiveAccountInfo(result: result)
    }
}
