import Foundation
import RobinHood
import FearlessUtils
import SoraKeystore

protocol StakingRebondConfirmationRelaychainStrategyOutput: AnyObject {
    func didReceiveStakingLedger(result: Result<StakingLedger?, Error>)
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>)
    func didReceiveController(result: Result<ChainAccountResponse?, Error>)
    func didReceiveStashItem(result: Result<StashItem?, Error>)
    func didReceiveActiveEra(result: Result<ActiveEraInfo?, Error>)
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>)

    func didSubmitRebonding(result: Result<String, Error>)
}

final class StakingRebondConfirmationRelaychainStrategy: AccountFetching {
    let stakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol
    private let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    private let runtimeService: RuntimeCodingServiceProtocol
    private let operationManager: OperationManagerProtocol
    private let feeProxy: ExtrinsicFeeProxyProtocol
    private let chainAsset: ChainAsset
    private let keystore: KeystoreProtocol
    private let wallet: MetaAccountModel
    private let connection: JSONRPCEngine
    private let accountRepository: AnyDataProviderRepository<MetaAccountModel>
    weak var output: StakingRebondConfirmationRelaychainStrategyOutput?
    private var stashItemProvider: StreamableProvider<StashItem>?
    private var activeEraProvider: AnyDataProvider<DecodedActiveEra>?
    private var ledgerProvider: AnyDataProvider<DecodedLedgerInfo>?
    private var accountInfoProvider: AnyDataProvider<DecodedAccountInfo>?
    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var extrinsicService: ExtrinsicServiceProtocol?
    private var signingWrapper: SigningWrapperProtocol?
    private let callFactory: SubstrateCallFactoryProtocol

    init(
        stakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        extrinsicService: ExtrinsicServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        operationManager: OperationManagerProtocol,
        keystore: KeystoreProtocol,
        connection: JSONRPCEngine,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        output: StakingRebondConfirmationRelaychainStrategyOutput?,
        callFactory: SubstrateCallFactoryProtocol
    ) {
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.extrinsicService = extrinsicService
        self.feeProxy = feeProxy
        self.runtimeService = runtimeService
        self.operationManager = operationManager
        self.chainAsset = chainAsset
        self.keystore = keystore
        self.connection = connection
        self.wallet = wallet
        self.accountRepository = accountRepository
        self.output = output
        self.callFactory = callFactory
    }

    private func handleController(accountItem: ChainAccountResponse) {
        extrinsicService = ExtrinsicService(
            accountId: accountItem.accountId,
            chainFormat: accountItem.chainFormat(),
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

extension StakingRebondConfirmationRelaychainStrategy: StakingRebondConfirmationStrategy {
    func setup() {
        if let address = wallet.fetch(for: chainAsset.chain.accountRequest())?.toAddress() {
            stashItemProvider = subscribeStashItemProvider(for: address)
        }

        activeEraProvider = subscribeActiveEra(for: chainAsset.chain.chainId)

        feeProxy.delegate = self
    }

    func submit(builderClosure: ExtrinsicBuilderClosure?) {
        guard let builderClosure = builderClosure, let signingWrapper = signingWrapper else {
            return
        }

        extrinsicService?.submit(
            builderClosure,
            signer: signingWrapper,
            runningIn: .main,
            completion: { [weak self] result in
                self?.output?.didSubmitRebonding(result: result)
            }
        )
    }

    func estimateFee(builderClosure: ExtrinsicBuilderClosure?, reuseIdentifier: String?) {
        guard let builderClosure = builderClosure,
              let extrinsicService = extrinsicService,
              let reuseIdentifier = reuseIdentifier else {
            return
        }

        feeProxy.estimateFee(
            using: extrinsicService,
            reuseIdentifier: reuseIdentifier,
            setupBy: builderClosure
        )
    }
}

extension StakingRebondConfirmationRelaychainStrategy: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(result: Result<AccountInfo?, Error>, accountId _: AccountId, chainAsset _: ChainAsset) {
        output?.didReceiveAccountInfo(result: result)
    }
}

extension StakingRebondConfirmationRelaychainStrategy: RelaychainStakingLocalStorageSubscriber, RelaychainStakingLocalSubscriptionHandler {
    func handleLedgerInfo(result: Result<StakingLedger?, Error>, accountId _: AccountId, chainId _: ChainModel.Id) {
        output?.didReceiveStakingLedger(result: result)
    }

    func handleActiveEra(result: Result<ActiveEraInfo?, Error>, chainId _: ChainModel.Id) {
        output?.didReceiveActiveEra(result: result)
    }

    func handleStashItem(result: Result<StashItem?, Error>, for _: AccountAddress) {
        do {
            let maybeStashItem = try result.get()

            clear(dataProvider: &accountInfoProvider)
            clear(dataProvider: &ledgerProvider)

            output?.didReceiveStashItem(result: result)

            if let stashItem = maybeStashItem,
               let accountId = try? AddressFactory.accountId(from: stashItem.controller, chain: chainAsset.chain) {
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
}

extension StakingRebondConfirmationRelaychainStrategy: AnyProviderAutoCleaning {}

extension StakingRebondConfirmationRelaychainStrategy: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        output?.didReceiveFee(result: result)
    }
}
