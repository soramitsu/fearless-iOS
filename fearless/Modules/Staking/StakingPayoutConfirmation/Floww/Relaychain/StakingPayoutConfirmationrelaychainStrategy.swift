import Foundation
import RobinHood
import BigInt

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

    private var batches: [Batch]?

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
        output: StakingPayoutConfirmationrelaychainStrategyOutput?
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
    }

    // MARK: - Private functions

    private func createExtrinsicBuilderClosure(for batches: [Batch]) -> ExtrinsicBuilderIndexedClosure? {
        let callFactory = SubstrateCallFactory()

        let closure: ExtrinsicBuilderIndexedClosure = { builder, index in
            try batches[index].forEach { payout in
                let payoutCall = try callFactory.payout(
                    validatorId: payout.validator,
                    era: payout.era
                )

                _ = try builder.adding(call: payoutCall)
            }

            return builder
        }

        return closure
    }

    private func createExtrinsicBuilderClosure(for batch: Batch) -> ExtrinsicBuilderClosure? {
        let callFactory = SubstrateCallFactory()

        let closure: ExtrinsicBuilderClosure = { builder in
            try batch.forEach { payout in
                let payoutCall = try callFactory.payout(
                    validatorId: payout.validator,
                    era: payout.era
                )

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
        guard let batches = batches, !batches.isEmpty else { return nil }

        let feeBatches = batches.count > 1 ?
            [batches[0], batches[batches.count - 1]] :
            [batches[0]]

        guard let feeClosure = createExtrinsicBuilderClosure(for: feeBatches) else { return nil }

        let feeOperation = extrinsicOperationFactory.estimateFeeOperation(
            feeClosure,
            numberOfExtrinsics: feeBatches.count
        )

        let dependencies = feeOperation.allOperations
        let precision = Int16(chainAsset.asset.precision)

        let mergeOperation = ClosureOperation<Decimal> {
            let results = try feeOperation.targetOperation.extractNoCancellableResultData()

            let fees: [Decimal] = try results.map { result in
                let dispatchInfo = try result.get()
                return BigUInt(dispatchInfo.fee).map {
                    Decimal.fromSubstrateAmount($0, precision: precision) ?? 0.0
                } ?? 0.0
            }

            return (fees.first ?? 0.0) * Decimal(batches.count - 1) + (fees.last ?? 0.0)
        }

        mergeOperation.addDependency(feeOperation.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: dependencies
        )
    }

    private func createBatchesOperationWrapper(
        from payouts: [PayoutInfo]
    ) -> CompoundOperationWrapper<[Batch]>? {
        guard let firstPayout = payouts.first,
              let feeClosure = createExtrinsicBuilderClosure(for: [firstPayout])
        else { return nil }

        let blockWeightsWrapper = createBlockWeightsWrapper()
        let feeWrapper = extrinsicOperationFactory.estimateFeeOperation(feeClosure)

        let batchesOperationWrapper = ClosureOperation<[Batch]> {
            let blockWeights = try blockWeightsWrapper.targetOperation.extractNoCancellableResultData()
            let fee = try feeWrapper.targetOperation.extractNoCancellableResultData()

            let batchSize = Int(Double(blockWeights.maxBlock) / Double(fee.weight) * 0.64)
            let batches = stride(from: 0, to: payouts.count, by: batchSize).map {
                Array(payouts[$0 ..< Swift.min($0 + batchSize, payouts.count)])
            }

            return batches
        }

        batchesOperationWrapper.addDependency(blockWeightsWrapper.targetOperation)
        batchesOperationWrapper.addDependency(feeWrapper.targetOperation)

        let dependencies = blockWeightsWrapper.allOperations + feeWrapper.allOperations

        return CompoundOperationWrapper(
            targetOperation: batchesOperationWrapper,
            dependencies: dependencies
        )
    }

    private func createBlockWeightsWrapper() -> CompoundOperationWrapper<BlockWeights> {
        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let blockWeightsOperation = StorageConstantOperation<BlockWeights>(path: .blockWeights)
        blockWeightsOperation.configurationBlock = {
            do {
                blockWeightsOperation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            } catch {
                blockWeightsOperation.result = .failure(error)
            }
        }

        blockWeightsOperation.addDependency(codingFactoryOperation)

        return CompoundOperationWrapper(
            targetOperation: blockWeightsOperation,
            dependencies: [codingFactoryOperation]
        )
    }

    private func generateBatches(completion closure: @escaping () -> Void) {
        guard let batchesOperation = createBatchesOperationWrapper(from: payouts) else {
            return
        }

        batchesOperation.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    self?.batches = try batchesOperation.targetOperation.extractNoCancellableResultData()
                    closure()
                } catch {
                    self?.output?.didReceiveFee(result: .failure(error))
                }
            }
        }

        operationManager.enqueue(operations: batchesOperation.allOperations, in: .transient)
    }
}

extension StakingPayoutConfirmationRelayachainStrategy: StakingPayoutConfirmationStrategy {
    func submitPayout(builderClosure _: ExtrinsicBuilderClosure?) {
        guard let batches = batches, !batches.isEmpty else { return }

        output?.didStartPayout()

        guard let closure = createExtrinsicBuilderClosure(for: batches) else { return }

        extrinsicService.submit(
            closure,
            signer: signer,
            runningIn: .main,
            numberOfExtrinsics: batches.count
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
        generateBatches {
            self.estimateFee(builderClosure: nil)
        }

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
