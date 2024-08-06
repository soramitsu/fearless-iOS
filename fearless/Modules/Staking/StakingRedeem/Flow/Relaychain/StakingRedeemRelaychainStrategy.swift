import Foundation
import RobinHood
import SoraKeystore
import SSFUtils
import BigInt
import SSFModels
import SSFRuntimeCodingService

protocol StakingRedeemRelaychainStrategyOutput: AnyObject {
    func didReceiveStakingLedger(result: Result<StakingLedger?, Error>)
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>)
    func didReceiveExistentialDeposit(result: Result<BigUInt, Error>)
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>)
    func didReceiveController(result: Result<ChainAccountResponse?, Error>)
    func didReceiveStashItem(result: Result<StashItem?, Error>)
    func didReceiveActiveEra(result: Result<ActiveEraInfo?, Error>)
    func didReceiveSlashingSpans(result: Result<SlashingSpans?, Error>)

    func didSubmitRedeeming(result: Result<String, Error>)
}

final class StakingRedeemRelaychainStrategy: RuntimeConstantFetching, AccountFetching {
    weak var output: StakingRedeemRelaychainStrategyOutput?
    let stakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol
    private let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    private let runtimeService: RuntimeCodingServiceProtocol
    private let operationManager: OperationManagerProtocol
    private let feeProxy: ExtrinsicFeeProxyProtocol
    private let slashesOperationFactory: SlashesOperationFactoryProtocol
    private let engine: JSONRPCEngine
    private let chainAsset: ChainAsset
    private let wallet: MetaAccountModel
    private let keystore: KeystoreProtocol
    private let accountRepository: AnyDataProviderRepository<MetaAccountModel>
    private var stashItemProvider: StreamableProvider<StashItem>?
    private var activeEraProvider: AnyDataProvider<DecodedActiveEra>?
    private var ledgerProvider: AnyDataProvider<DecodedLedgerInfo>?
    private var accountInfoProvider: AnyDataProvider<DecodedAccountInfo>?
    private var priceProvider: AnySingleValueProvider<[PriceData]>?
    private var extrinsicService: ExtrinsicServiceProtocol?
    private var signingWrapper: SigningWrapperProtocol?

    init(
        output: StakingRedeemRelaychainStrategyOutput?,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        stakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        extrinsicService: ExtrinsicServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        slashesOperationFactory: SlashesOperationFactoryProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        engine: JSONRPCEngine,
        operationManager: OperationManagerProtocol,
        keystore: KeystoreProtocol,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>
    ) {
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.feeProxy = feeProxy
        self.extrinsicService = extrinsicService
        self.slashesOperationFactory = slashesOperationFactory
        self.runtimeService = runtimeService
        self.operationManager = operationManager
        self.engine = engine
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.keystore = keystore
        self.accountRepository = accountRepository
        self.output = output
    }

    private func handleController(accountItem: ChainAccountResponse) {
        extrinsicService = ExtrinsicService(
            accountId: accountItem.accountId,
            chainFormat: accountItem.chainFormat(),
            cryptoType: accountItem.cryptoType,
            runtimeRegistry: runtimeService,
            engine: engine,
            operationManager: operationManager
        )

        signingWrapper = SigningWrapper(
            keystore: keystore,
            metaId: accountItem.walletId,
            accountResponse: accountItem
        )
    }

    private func fetchSlashingSpansForStash(
        _ stash: AccountAddress
    ) {
        let wrapper = slashesOperationFactory.createSlashingSpansOperationForStash(
            stash,
            engine: engine,
            runtimeService: runtimeService,
            chainAsset: chainAsset
        )

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                if let result = wrapper.targetOperation.result {
                    self?.output?.didReceiveSlashingSpans(result: result)
                } else {
                    self?.output?.didReceiveSlashingSpans(result: .failure(BaseOperationError.unexpectedDependentResult))
                }
            }
        }

        operationManager.enqueue(
            operations: wrapper.allOperations,
            in: .transient
        )
    }
}

extension StakingRedeemRelaychainStrategy: StakingRedeemStrategy {
    func setup() {
        if let address = wallet.fetch(for: chainAsset.chain.accountRequest())?.toAddress() {
            stashItemProvider = subscribeStashItemProvider(for: address)
        }

        activeEraProvider = subscribeActiveEra(for: chainAsset.chain.chainId)

        fetchConstant(
            for: .existentialDeposit,
            runtimeCodingService: runtimeService,
            operationManager: operationManager
        ) { [weak self] (result: Result<BigUInt, Error>) in
            self?.output?.didReceiveExistentialDeposit(result: result)
        }

        feeProxy.delegate = self
    }

    func estimateFee(builderClosure: ExtrinsicBuilderClosure?, reuseIdentifier: String?) {
        guard let extrinsicService = extrinsicService,
              let builderClosure = builderClosure,
              let reuseIdentifier = reuseIdentifier else {
            output?.didReceiveFee(result: .failure(CommonError.undefined))
            return
        }

        feeProxy.estimateFee(
            using: extrinsicService,
            reuseIdentifier: reuseIdentifier,
            setupBy: builderClosure
        )
    }

    func submit(builderClosure: ExtrinsicBuilderClosure?) {
        guard
            let extrinsicService = extrinsicService,
            let signingWrapper = signingWrapper,
            let builderClosure = builderClosure else {
            output?.didSubmitRedeeming(result: .failure(CommonError.undefined))
            return
        }

        extrinsicService.submit(
            builderClosure,
            signer: signingWrapper,
            runningIn: .main
        ) { [weak self] result in
            self?.output?.didSubmitRedeeming(result: result)
        }
    }
}

extension StakingRedeemRelaychainStrategy: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(result: Result<AccountInfo?, Error>, accountId _: AccountId, chainAsset _: ChainAsset) {
        output?.didReceiveAccountInfo(result: result)
    }
}

extension StakingRedeemRelaychainStrategy: RelaychainStakingLocalStorageSubscriber, RelaychainStakingLocalSubscriptionHandler {
    func handleStashItem(result: Result<StashItem?, Error>, for _: AccountAddress) {
        do {
            let maybeStashItem = try result.get()

            accountInfoSubscriptionAdapter.reset()
            clear(dataProvider: &ledgerProvider)

            output?.didReceiveStashItem(result: result)

            if let stashItem = maybeStashItem,
               let accountId = try? AddressFactory.accountId(from: stashItem.controller, chain: chainAsset.chain) {
                fetchSlashingSpansForStash(stashItem.stash)

                ledgerProvider = subscribeLedgerInfo(for: accountId, chainAsset: chainAsset)
                accountInfoSubscriptionAdapter.subscribe(chainAsset: chainAsset, accountId: accountId, handler: self)

                fetchChainAccount(
                    chain: chainAsset.chain,
                    address: stashItem.controller,
                    from: accountRepository,
                    operationManager: operationManager
                ) { [weak self] result in
                    if case let .success(maybeController) = result, let controller = maybeController {
                        self?.handleController(accountItem: controller)
                    }

                    self?.output?.didReceiveController(result: result)
                }

            } else {
                output?.didReceiveStakingLedger(result: .success(nil))
                output?.didReceiveAccountInfo(result: .success(nil))
            }

        } catch {
            output?.didReceiveStashItem(result: .failure(error))
            output?.didReceiveAccountInfo(result: .failure(error))
            output?.didReceiveStakingLedger(result: .failure(error))
        }
    }

    func handleLedgerInfo(result: Result<StakingLedger?, Error>, accountId _: AccountId, chainId _: ChainModel.Id) {
        output?.didReceiveStakingLedger(result: result)
    }

    func handleActiveEra(result: Result<ActiveEraInfo?, Error>, chainId _: ChainModel.Id) {
        output?.didReceiveActiveEra(result: result)
    }
}

extension StakingRedeemRelaychainStrategy: AnyProviderAutoCleaning {}

extension StakingRedeemRelaychainStrategy: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        output?.didReceiveFee(result: result)
    }
}
