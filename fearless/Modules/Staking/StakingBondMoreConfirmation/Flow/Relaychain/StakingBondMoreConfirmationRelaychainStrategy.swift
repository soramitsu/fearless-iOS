import Foundation
import RobinHood
import FearlessUtils
import SoraKeystore

protocol StakingBondMoreConfirmationRelaychainStrategyOutput: AnyObject {
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>)
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>)
    func didReceiveStash(result: Result<ChainAccountResponse?, Error>)
    func didReceiveStashItem(result: Result<StashItem?, Error>)
    func didSubmitBonding(result: Result<String, Error>)
}

final class StakingBondMoreConfirmationRelaychainStrategy: AccountFetching {
    let stakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol
    let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol

    private weak var output: StakingBondMoreConfirmationRelaychainStrategyOutput?
    private let chainAsset: ChainAsset
    private let wallet: MetaAccountModel
    private var extrinsicService: ExtrinsicServiceProtocol
    private let feeProxy: ExtrinsicFeeProxyProtocol
    private let runtimeService: RuntimeCodingServiceProtocol
    private let operationManager: OperationManagerProtocol
    private let accountRepository: AnyDataProviderRepository<MetaAccountModel>
    private let connection: JSONRPCEngine
    private let keystore: KeystoreProtocol

    private var balanceProvider: AnyDataProvider<DecodedAccountInfo>?
    private var stashItemProvider: StreamableProvider<StashItem>?
    private var signingWrapper: SigningWrapperProtocol

    private lazy var callFactory = SubstrateCallFactory()

    init(
        stakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        extrinsicService: ExtrinsicServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        operationManager: OperationManagerProtocol,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        connection: JSONRPCEngine,
        keystore: KeystoreProtocol,
        signingWrapper: SigningWrapperProtocol,
        output: StakingBondMoreConfirmationRelaychainStrategyOutput?
    ) {
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.extrinsicService = extrinsicService
        self.feeProxy = feeProxy
        self.runtimeService = runtimeService
        self.operationManager = operationManager
        self.accountRepository = accountRepository
        self.connection = connection
        self.keystore = keystore
        self.signingWrapper = signingWrapper
        self.output = output
    }

    func handleStashAccountItem(_ accountItem: ChainAccountResponse) {
        extrinsicService = ExtrinsicService(
            accountId: accountItem.accountId,
            chainFormat: chainAsset.chain.chainFormat,
            cryptoType: accountItem.cryptoType,
            runtimeRegistry: runtimeService,
            engine: connection,
            operationManager: operationManager
        )

        signingWrapper = SigningWrapper(
            keystore: keystore,
            metaId: accountItem.walletId,
            accountResponse: accountItem
        )
    }
}

extension StakingBondMoreConfirmationRelaychainStrategy: StakingBondMoreConfirmationStrategy {
    func setup() {
        if let address = wallet.fetch(for: chainAsset.chain.accountRequest())?.toAddress() {
            stashItemProvider = subscribeStashItemProvider(for: address)
        }

        feeProxy.delegate = self
    }

    func estimateFee(builderClosure: ExtrinsicBuilderClosure?, reuseIdentifier: String?) {
        guard let builderClosure = builderClosure,
              let reuseIdentifier = reuseIdentifier else {
            return
        }

        feeProxy.estimateFee(using: extrinsicService, reuseIdentifier: reuseIdentifier, setupBy: builderClosure)
    }

    func submit(builderClosure: ExtrinsicBuilderClosure?) {
        guard let builderClosure = builderClosure else {
            return
        }

        extrinsicService.submit(
            builderClosure,
            signer: signingWrapper,
            runningIn: .main,
            completion: { [weak self] result in
                self?.output?.didSubmitBonding(result: result)
            }
        )
    }
}

extension StakingBondMoreConfirmationRelaychainStrategy: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(result: Result<AccountInfo?, Error>, accountId _: AccountId, chainAsset _: ChainAsset) {
        output?.didReceiveAccountInfo(result: result)
    }
}

extension StakingBondMoreConfirmationRelaychainStrategy: RelaychainStakingLocalStorageSubscriber, RelaychainStakingLocalSubscriptionHandler {
    func handleStashItem(result: Result<StashItem?, Error>, for _: AccountAddress) {
        do {
            let maybeStashItem = try result.get()

            accountInfoSubscriptionAdapter.reset()

            output?.didReceiveStashItem(result: result)

            if let stashItem = maybeStashItem {
                if let accountId = try? AddressFactory.accountId(from: stashItem.stash, chain: chainAsset.chain) {
                    accountInfoSubscriptionAdapter.subscribe(chainAsset: chainAsset, accountId: accountId, handler: self)
                }

                fetchChainAccount(
                    chain: chainAsset.chain,
                    address: stashItem.stash,
                    from: accountRepository,
                    operationManager: operationManager
                ) { [weak self] result in
                    if case let .success(stash) = result, let stash = stash {
                        self?.handleStashAccountItem(stash)
                    }

                    self?.output?.didReceiveStash(result: result)
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

extension StakingBondMoreConfirmationRelaychainStrategy: AnyProviderAutoCleaning {}

extension StakingBondMoreConfirmationRelaychainStrategy: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        output?.didReceiveFee(result: result)
    }
}
