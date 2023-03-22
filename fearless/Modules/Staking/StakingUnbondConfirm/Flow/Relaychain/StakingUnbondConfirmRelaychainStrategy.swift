import Foundation
import FearlessUtils
import SoraKeystore
import RobinHood
import BigInt

protocol StakingUnbondConfirmRelaychainStrategyOutput: AnyObject {
    func didReceiveStakingLedger(result: Result<StakingLedger?, Error>)
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>)
    func didReceiveExistentialDeposit(result: Result<BigUInt, Error>)
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>)
    func didReceiveController(result: Result<ChainAccountResponse?, Error>)
    func didReceiveStashItem(result: Result<StashItem?, Error>)
    func didReceivePayee(result: Result<RewardDestinationArg?, Error>)
    func didReceiveMinBonded(result: Result<BigUInt?, Error>)
    func didReceiveNomination(result: Result<Nomination?, Error>)
    func didSubmitUnbonding(result: Result<String, Error>)
}

final class StakingUnbondConfirmRelaychainStrategy: AccountFetching, RuntimeConstantFetching {
    weak var output: StakingUnbondConfirmRelaychainStrategyOutput?
    let stakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol
    private let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    private let runtimeService: RuntimeCodingServiceProtocol
    private let operationManager: OperationManagerProtocol
    private let feeProxy: ExtrinsicFeeProxyProtocol
    private let chainAsset: ChainAsset
    private let wallet: MetaAccountModel
    private let connection: JSONRPCEngine
    private let keystore: KeystoreProtocol
    private let accountRepository: AnyDataProviderRepository<MetaAccountModel>
    private var stashItemProvider: StreamableProvider<StashItem>?
    private var minBondedProvider: AnyDataProvider<DecodedBigUInt>?
    private var ledgerProvider: AnyDataProvider<DecodedLedgerInfo>?
    private var accountInfoProvider: AnyDataProvider<DecodedAccountInfo>?
    private var nominationProvider: AnyDataProvider<DecodedNomination>?
    private var payeeProvider: AnyDataProvider<DecodedPayee>?
    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var extrinsicService: ExtrinsicServiceProtocol?
    private var signingWrapper: SigningWrapperProtocol?
    private let callFactory: SubstrateCallFactoryProtocol

    init(
        output: StakingUnbondConfirmRelaychainStrategyOutput?,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        stakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        operationManager: OperationManagerProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        connection: JSONRPCEngine,
        keystore: KeystoreProtocol,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        callFactory: SubstrateCallFactoryProtocol
    ) {
        self.output = output
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.runtimeService = runtimeService
        self.operationManager = operationManager
        self.feeProxy = feeProxy
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.connection = connection
        self.keystore = keystore
        self.accountRepository = accountRepository
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

extension StakingUnbondConfirmRelaychainStrategy: StakingUnbondConfirmStrategy {
    func setup() {
        if let address = wallet.fetch(for: chainAsset.chain.accountRequest())?.toAddress() {
            stashItemProvider = subscribeStashItemProvider(for: address)
        }

        minBondedProvider = subscribeToMinNominatorBond(for: chainAsset.chain.chainId)

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
            output?.didSubmitUnbonding(result: .failure(CommonError.undefined))
            return
        }

        extrinsicService.submit(
            builderClosure,
            signer: signingWrapper,
            runningIn: .main
        ) { [weak self] result in
            self?.output?.didSubmitUnbonding(result: result)
        }
    }
}

extension StakingUnbondConfirmRelaychainStrategy: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(result: Result<AccountInfo?, Error>, accountId _: AccountId, chainAsset _: ChainAsset) {
        output?.didReceiveAccountInfo(result: result)
    }
}

extension StakingUnbondConfirmRelaychainStrategy: RelaychainStakingLocalStorageSubscriber, RelaychainStakingLocalSubscriptionHandler {
    func handleLedgerInfo(result: Result<StakingLedger?, Error>, accountId _: AccountId, chainId _: ChainModel.Id) {
        output?.didReceiveStakingLedger(result: result)
    }

    func handlePayee(result: Result<RewardDestinationArg?, Error>, accountId _: AccountId, chainId _: ChainModel.Id) {
        output?.didReceivePayee(result: result)
    }

    func handleMinNominatorBond(result: Result<BigUInt?, Error>, chainId _: ChainModel.Id) {
        output?.didReceiveMinBonded(result: result)
    }

    func handleNomination(result: Result<Nomination?, Error>, accountId _: AccountId, chainId _: ChainModel.Id) {
        output?.didReceiveNomination(result: result)
    }

    func handleStashItem(result: Result<StashItem?, Error>, for _: AccountAddress) {
        do {
            let maybeStashItem = try result.get()

            clear(dataProvider: &accountInfoProvider)
            clear(dataProvider: &ledgerProvider)
            clear(dataProvider: &payeeProvider)
            clear(dataProvider: &nominationProvider)

            output?.didReceiveStashItem(result: result)

            if let stashItem = maybeStashItem,
               let accountId = try? AddressFactory.accountId(from: stashItem.controller, chain: chainAsset.chain) {
                ledgerProvider = subscribeLedgerInfo(
                    for: accountId,
                    chainAsset: chainAsset
                )

                accountInfoSubscriptionAdapter.subscribe(chainAsset: chainAsset, accountId: accountId, handler: self)

                payeeProvider = subscribePayee(for: accountId, chainAsset: chainAsset)

                nominationProvider = subscribeNomination(for: accountId, chainAsset: chainAsset)

                fetchChainAccount(chain: chainAsset.chain, address: stashItem.controller, from: accountRepository, operationManager: operationManager) { [weak self] result in
                    guard let self = self else {
                        return
                    }
                    if case let .success(account) = result, let account = account {
                        self.handleController(accountItem: account)
                    }

                    self.output?.didReceiveController(result: result)
                }

            } else {
                output?.didReceiveStakingLedger(result: .success(nil))
                output?.didReceiveAccountInfo(result: .success(nil))
                output?.didReceivePayee(result: .success(nil))
                output?.didReceiveNomination(result: .success(nil))
            }

        } catch {
            output?.didReceiveStashItem(result: .failure(error))
            output?.didReceiveAccountInfo(result: .failure(error))
            output?.didReceiveStakingLedger(result: .failure(error))
            output?.didReceivePayee(result: .failure(error))
            output?.didReceiveNomination(result: .failure(error))
        }
    }
}

extension StakingUnbondConfirmRelaychainStrategy: AnyProviderAutoCleaning {}

extension StakingUnbondConfirmRelaychainStrategy: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        output?.didReceiveFee(result: result)
    }
}
