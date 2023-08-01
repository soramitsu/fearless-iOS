import Foundation
import RobinHood
import BigInt
import SSFModels

protocol StakingPayoutConfirmationrelaychainStrategyOutput {
    func didRecieve(account: ChainAccountResponse, rewardAmount: Decimal)
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>)
    func didReceiveRewardDestination(result: Result<RewardDestination<DisplayAddress>?, Error>)
    func didReceiveFee(result: Result<Decimal, Error>)
    func didStartPayout()
    func didCompletePayout(txHashes: [String])
    func didFailPayout(error: Error)
}

final class StakingPayoutConfirmationRelayachainStrategy: AccountFetching {
    private let extrinsicOperationFactory: ExtrinsicOperationFactoryProtocol
    private let extrinsicService: ExtrinsicServiceProtocol
    private let runtimeService: RuntimeCodingServiceProtocol
    private let signer: SigningWrapperProtocol

    let stakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol
    let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol

    private let accountRepository: AnyDataProviderRepository<MetaAccountModel>
    private let operationManager: OperationManagerProtocol
    private let logger: LoggerProtocol?
    private let payouts: [PayoutInfo]
    private let chainAsset: ChainAsset
    private let wallet: MetaAccountModel
    private let output: StakingPayoutConfirmationrelaychainStrategyOutput?
    private let callFactory: SubstrateCallFactoryProtocol

    private var balanceProvider: AnyDataProvider<DecodedAccountInfo>?
    private var stashItemProvider: StreamableProvider<StashItem>?
    private var stashControllerProvider: StreamableProvider<StashItem>?
    private var payeeProvider: AnyDataProvider<DecodedPayee>?

    private var stashItem: StashItem?

    init(
        stakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        extrinsicOperationFactory: ExtrinsicOperationFactoryProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        signer: SigningWrapperProtocol,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol? = nil,
        wallet: MetaAccountModel,
        payouts: [PayoutInfo],
        chainAsset: ChainAsset,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        output: StakingPayoutConfirmationrelaychainStrategyOutput?,
        callFactory: SubstrateCallFactoryProtocol
    ) {
        self.extrinsicOperationFactory = extrinsicOperationFactory
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.extrinsicService = extrinsicService
        self.runtimeService = runtimeService
        self.signer = signer
        self.operationManager = operationManager
        self.logger = logger
        self.wallet = wallet
        self.payouts = payouts
        self.chainAsset = chainAsset
        self.accountRepository = accountRepository
        self.output = output
        self.callFactory = callFactory
    }

    // MARK: - Private functions

    private func createExtrinsicBuilderClosure(for payouts: [PayoutInfo]) -> ExtrinsicBuilderIndexedClosure? {
        let closure: ExtrinsicBuilderIndexedClosure = { [weak self] builder, _ in
            try payouts.forEach { payout in
                guard let payoutCall = try self?.callFactory.payout(
                    validatorId: payout.validator,
                    era: payout.era
                ) else {
                    return
                }

                _ = try builder.adding(call: payoutCall)
            }

            return builder
        }

        return closure
    }

    private func provideRewardAmount() {
        let rewardAmount = payouts.map(\.reward).reduce(0, +)

        guard let account = wallet.fetch(for: chainAsset.chain.accountRequest()) else {
            return
        }

        output?.didRecieve(
            account: account,
            rewardAmount: rewardAmount
        )
    }

    private func provideRewardDestination(with payee: RewardDestinationArg) {
        guard let stashItem = stashItem else {
            output?.didReceiveRewardDestination(result: .failure(CommonError.undefined))
            return
        }

        do {
            let rewardDestination = try RewardDestination(
                payee: payee,
                stashItem: stashItem,
                chainFormat: chainAsset.chain.chainFormat
            )

            switch rewardDestination {
            case .restake:
                output?.didReceiveRewardDestination(result: .success(.restake))

            case let .payout(payoutAddress):
                fetchChainAccount(
                    chain: chainAsset.chain,
                    address: payoutAddress,
                    from: accountRepository,
                    operationManager: operationManager
                ) { [weak self] result in
                    switch result {
                    case let .success(account):
                        let displayAddress = DisplayAddress(
                            address: payoutAddress,
                            username: account?.name ?? ""
                        )

                        let destination: RewardDestination = .payout(account: displayAddress)
                        self?.output?.didReceiveRewardDestination(result: .success(destination))

                    case let .failure(error):
                        self?.output?.didReceiveRewardDestination(result: .failure(error))
                    }
                }
            }
        } catch {
            logger?.error("Did receive reward destination error: \(error)")
        }
    }

    private func createFeeOperationWrapper() -> CompoundOperationWrapper<Decimal>? {
        let payoutsUnwrapped = payouts
        guard !payoutsUnwrapped.isEmpty else { return nil }
        guard let feeClosure = createExtrinsicBuilderClosure(for: payouts) else { return nil }

        let feeOperation = extrinsicOperationFactory.estimateFeeOperation(
            feeClosure,
            numberOfExtrinsics: payoutsUnwrapped.count
        )

        let dependencies = feeOperation.allOperations
        let precision = Int16(chainAsset.asset.precision)

        let mergeOperation = ClosureOperation<Decimal> {
            let results = try feeOperation.targetOperation.extractNoCancellableResultData()

            let fees: [Decimal] = try results.map { result in
                let dispatchInfo = try result.get()
                return BigUInt(string: dispatchInfo.fee).map {
                    Decimal.fromSubstrateAmount($0, precision: precision) ?? 0.0
                } ?? 0.0
            }
            return (fees.first ?? 0.0) * Decimal(payoutsUnwrapped.count - 1) + (fees.last ?? 0.0)
        }

        mergeOperation.addDependency(feeOperation.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: dependencies
        )
    }
}

extension StakingPayoutConfirmationRelayachainStrategy: StakingPayoutConfirmationStrategy {
    func submitPayout(builderClosure _: ExtrinsicBuilderClosure?) {
        let payoutsUnwrapped = payouts
        guard !payoutsUnwrapped.isEmpty else { return }

        output?.didStartPayout()

        guard let closure = createExtrinsicBuilderClosure(for: payoutsUnwrapped) else { return }

        extrinsicService.submit(
            closure,
            signer: signer,
            runningIn: .main,
            numberOfExtrinsics: payoutsUnwrapped.count
        ) { [weak self] result in
            do {
                let txHashes: [String] = try result.map { result in
                    try result.get()
                }

                self?.output?.didCompletePayout(txHashes: txHashes)
            } catch {
                self?.output?.didFailPayout(error: error)
            }
        }
    }

    func setup() {
        estimateFee(builderClosure: nil)

        if let address = wallet.fetch(for: chainAsset.chain.accountRequest())?.toAddress() {
            stashItemProvider = subscribeStashItemProvider(for: address)
        }

        if let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId {
            accountInfoSubscriptionAdapter.subscribe(chainAsset: chainAsset, accountId: accountId, handler: self)
        }

        provideRewardAmount()
    }

    func estimateFee(builderClosure _: ExtrinsicBuilderClosure?) {
        guard let feeOperation = createFeeOperationWrapper() else {
            output?.didReceiveFee(result: .failure(CommonError.undefined))
            return
        }

        feeOperation.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let fee = try feeOperation.targetOperation.extractNoCancellableResultData()
                    self?.output?.didReceiveFee(result: .success(fee))
                } catch {
                    self?.output?.didReceiveFee(result: .failure(error))
                }
            }
        }

        operationManager.enqueue(operations: feeOperation.allOperations, in: .transient)
    }
}

extension StakingPayoutConfirmationRelayachainStrategy: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(result: Result<AccountInfo?, Error>, accountId _: AccountId, chainAsset _: ChainAsset) {
        output?.didReceiveAccountInfo(result: result)
    }
}

extension StakingPayoutConfirmationRelayachainStrategy: RelaychainStakingLocalStorageSubscriber, RelaychainStakingLocalSubscriptionHandler {
    func handlePayee(result: Result<RewardDestinationArg?, Error>, accountId _: AccountId, chainId _: ChainModel.Id) {
        switch result {
        case let .success(payee):
            guard let payee = payee else {
                return
            }

            provideRewardDestination(with: payee)

        case let .failure(error):
            output?.didReceiveRewardDestination(result: .failure(error))
        }
    }

    func handleStashItem(result: Result<StashItem?, Error>, for _: AccountAddress) {
        do {
            stashItem = try result.get()

            clear(dataProvider: &payeeProvider)

            if let stashItem = stashItem,
               let accountId = try? AddressFactory.accountId(from: stashItem.stash, chain: chainAsset.chain) {
                payeeProvider = subscribePayee(for: accountId, chainAsset: chainAsset)
            } else {
                output?.didReceiveRewardDestination(result: .success(nil))
            }
        } catch {
            output?.didReceiveRewardDestination(result: .failure(error))
            logger?.error("Stash subscription item error: \(error)")
        }
    }
}

// MARK: - SingleValueProviderSubscriber, SingleValueSubscriptionHandler, AnyProviderAutoCleaning

extension StakingPayoutConfirmationRelayachainStrategy: AnyProviderAutoCleaning {}

// MARK: - SubstrateProviderSubscriber, SubstrateProviderSubscriptionHandler
