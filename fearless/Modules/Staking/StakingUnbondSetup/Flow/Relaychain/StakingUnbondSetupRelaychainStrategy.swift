import Foundation
import SSFUtils
import RobinHood
import Web3
import SSFModels

protocol StakingUnbondSetupRelaychainStrategyOutput: AnyObject {
    func didReceiveStakingLedger(result: Result<StakingLedger?, Error>)
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>)
    func didReceiveBondingDuration(result: Result<UInt32, Error>)
    func didReceiveExistentialDeposit(result: Result<BigUInt, Error>)
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>)
    func didReceiveController(result: Result<ChainAccountResponse?, Error>)
    func didReceiveStashItem(result: Result<StashItem?, Error>)
    func didReceivePayee(result: Result<RewardDestinationArg?, Error>)
    func didReceiveMinBonded(result: Result<BigUInt?, Error>)
    func didReceiveNomination(result: Result<Nomination?, Error>)
    func didReceiveNewExtrinsicService()
}

final class StakingUnbondSetupRelaychainStrategy: RuntimeConstantFetching, AccountFetching {
    init(
        stakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        operationManager: OperationManagerProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        connection: JSONRPCEngine,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        output: StakingUnbondSetupRelaychainStrategyOutput?,
        extrinsicService: ExtrinsicServiceProtocol?,
        callFactory: SubstrateCallFactoryProtocol
    ) {
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.runtimeService = runtimeService
        self.operationManager = operationManager
        self.feeProxy = feeProxy
        self.wallet = wallet
        self.chainAsset = chainAsset
        self.connection = connection
        self.accountRepository = accountRepository
        self.output = output
        self.extrinsicService = extrinsicService
        self.callFactory = callFactory
    }

    let stakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol
    let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol

    private let runtimeService: RuntimeCodingServiceProtocol
    private let operationManager: OperationManagerProtocol
    private let feeProxy: ExtrinsicFeeProxyProtocol
    private let wallet: MetaAccountModel
    private let chainAsset: ChainAsset
    private let connection: JSONRPCEngine
    private let accountRepository: AnyDataProviderRepository<MetaAccountModel>
    private weak var output: StakingUnbondSetupRelaychainStrategyOutput?
    private let callFactory: SubstrateCallFactoryProtocol

    private var stashItemProvider: StreamableProvider<StashItem>?
    private var ledgerProvider: AnyDataProvider<DecodedLedgerInfo>?
    private var accountInfoProvider: AnyDataProvider<DecodedAccountInfo>?
    private var payeeProvider: AnyDataProvider<DecodedPayee>?
    private var nominationProvider: AnyDataProvider<DecodedNomination>?
    private var minBondedProvider: AnyDataProvider<DecodedBigUInt>?
    private var extrinsicService: ExtrinsicServiceProtocol?

    private func handleController(accountItem: ChainAccountResponse) {
        extrinsicService = ExtrinsicService(
            accountId: accountItem.accountId,
            chainFormat: accountItem.chainFormat(),
            cryptoType: accountItem.cryptoType,
            runtimeRegistry: runtimeService,
            engine: connection,
            operationManager: operationManager
        )

        output?.didReceiveNewExtrinsicService()
    }
}

extension StakingUnbondSetupRelaychainStrategy: StakingUnbondSetupStrategy {
    func estimateFee(builderClosure: ExtrinsicBuilderClosure?, reuseIdentifier: String) {
        guard let builderClosure = builderClosure,
              let extrinsicService = extrinsicService
        else {
            return
        }

        feeProxy.estimateFee(
            using: extrinsicService,
            reuseIdentifier: reuseIdentifier,
            setupBy: builderClosure
        )
    }

    func setup() {
        if let address = wallet.fetch(for: chainAsset.chain.accountRequest())?.toAddress() {
            stashItemProvider = subscribeStashItemProvider(for: address)
        }

        fetchConstant(
            for: .lockUpPeriod,
            runtimeCodingService: runtimeService,
            operationManager: operationManager
        ) { [weak self] (result: Result<UInt32, Error>) in
            self?.output?.didReceiveBondingDuration(result: result)
        }

        fetchConstant(
            for: .existentialDeposit,
            runtimeCodingService: runtimeService,
            operationManager: operationManager
        ) { [weak self] (result: Result<BigUInt, Error>) in
            self?.output?.didReceiveExistentialDeposit(result: result)
        }

        feeProxy.delegate = self

        minBondedProvider = subscribeToMinNominatorBond(for: chainAsset.chain.chainId)
    }
}

extension StakingUnbondSetupRelaychainStrategy: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(result: Result<AccountInfo?, Error>, accountId _: AccountId, chainAsset _: ChainAsset) {
        output?.didReceiveAccountInfo(result: result)
    }
}

extension StakingUnbondSetupRelaychainStrategy: RelaychainStakingLocalStorageSubscriber, RelaychainStakingLocalSubscriptionHandler, AnyProviderAutoCleaning {
    func handleNomination(result: Result<Nomination?, Error>, accountId _: AccountId, chainId _: ChainModel.Id) {
        output?.didReceiveNomination(result: result)
    }

    func handleMinNominatorBond(result: Result<BigUInt?, Error>, chainId _: ChainModel.Id) {
        output?.didReceiveMinBonded(result: result)
    }

    func handlePayee(result: Result<RewardDestinationArg?, Error>, accountId _: AccountId, chainId _: ChainModel.Id) {
        output?.didReceivePayee(result: result)
    }

    func handleStashItem(result: Result<StashItem?, Error>, for _: AccountAddress) {
        do {
            let maybeStashItem = try result.get()

            clear(dataProvider: &accountInfoProvider)
            clear(dataProvider: &ledgerProvider)
            clear(dataProvider: &payeeProvider)
            clear(dataProvider: &nominationProvider)

            output?.didReceiveStashItem(result: result)

            if let stashItem = maybeStashItem {
                fetchChainAccount(
                    chain: chainAsset.chain,
                    address: stashItem.controller,
                    from: accountRepository,
                    operationManager: operationManager
                ) { [weak self] result in
                    guard let self = self else {
                        return
                    }
                    if case let .success(account) = result, let account = account {
                        self.ledgerProvider = self.subscribeLedgerInfo(
                            for: account.accountId,
                            chainAsset: self.chainAsset
                        )

                        self.payeeProvider = self.subscribePayee(
                            for: account.accountId,
                            chainAsset: self.chainAsset
                        )

                        self.nominationProvider = self.subscribeNomination(
                            for: account.accountId,
                            chainAsset: self.chainAsset
                        )

                        self.accountInfoSubscriptionAdapter.subscribe(
                            chainAsset: self.chainAsset,
                            accountId: account.accountId,
                            handler: self
                        )

                        self.handleController(accountItem: account)
                    }

                    self.output?.didReceiveController(result: result)
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

    func handleAccountInfo(result: Result<AccountInfo?, Error>, address _: AccountAddress) {
        output?.didReceiveAccountInfo(result: result)
    }
}

extension StakingUnbondSetupRelaychainStrategy: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        output?.didReceiveFee(result: result)
    }
}
