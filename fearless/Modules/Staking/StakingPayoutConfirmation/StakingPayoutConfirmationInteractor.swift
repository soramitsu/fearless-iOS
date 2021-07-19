import Foundation
import SoraKeystore
import CommonWallet
import RobinHood
import IrohaCrypto
import BigInt

final class StakingPayoutConfirmationInteractor {
    typealias Batch = [PayoutInfo]
    internal let singleValueProviderFactory: SingleValueProviderFactoryProtocol
    internal let substrateProviderFactory: SubstrateDataProviderFactoryProtocol

    private let extrinsicOperationFactory: ExtrinsicOperationFactoryProtocol
    private let extrinsicService: ExtrinsicServiceProtocol
    private let runtimeService: RuntimeCodingServiceProtocol
    private let signer: SigningWrapperProtocol

    private let accountRepository: AnyDataProviderRepository<AccountItem>
    private let operationManager: OperationManagerProtocol
    private let logger: LoggerProtocol?
    private let selectedAccount: AccountItem
    private let payouts: [PayoutInfo]
    private let chain: Chain
    private let assetId: WalletAssetId

    private var batches: [Batch]?

    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var balanceProvider: AnyDataProvider<DecodedAccountInfo>?
    private var stashItemProvider: StreamableProvider<StashItem>?
    private var stashControllerProvider: StreamableProvider<StashItem>?
    private var payeeProvider: AnyDataProvider<DecodedPayee>?

    private var stashItem: StashItem?

    weak var presenter: StakingPayoutConfirmationInteractorOutputProtocol!

    init(
        singleValueProviderFactory: SingleValueProviderFactoryProtocol,
        substrateProviderFactory: SubstrateDataProviderFactoryProtocol,
        extrinsicOperationFactory: ExtrinsicOperationFactoryProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        signer: SigningWrapperProtocol,
        accountRepository: AnyDataProviderRepository<AccountItem>,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol? = nil,
        selectedAccount: AccountItem,
        payouts: [PayoutInfo],
        chain: Chain,
        assetId: WalletAssetId
    ) {
        self.singleValueProviderFactory = singleValueProviderFactory
        self.substrateProviderFactory = substrateProviderFactory
        self.extrinsicOperationFactory = extrinsicOperationFactory
        self.extrinsicService = extrinsicService
        self.runtimeService = runtimeService
        self.signer = signer
        self.accountRepository = accountRepository
        self.operationManager = operationManager
        self.logger = logger
        self.selectedAccount = selectedAccount
        self.payouts = payouts
        self.chain = chain
        self.assetId = assetId
    }

    // MARK: - Private functions

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

        presenter.didRecieve(
            account: selectedAccount,
            rewardAmount: rewardAmount
        )
    }

    private func provideRewardDestination(with payee: RewardDestinationArg) {
        guard let stashItem = stashItem else {
            presenter.didReceiveRewardDestination(result: .failure(CommonError.undefined))
            return
        }

        do {
            let rewardDestination = try RewardDestination(
                payee: payee,
                stashItem: stashItem,
                chain: chain
            )

            switch rewardDestination {
            case .restake:
                presenter.didReceiveRewardDestination(result: .success(.restake))

            case let .payout(payoutAddress):
                let queryOperation = accountRepository
                    .fetchOperation(by: payoutAddress, options: RepositoryFetchOptions())

                queryOperation.completionBlock = {
                    DispatchQueue.main.async {
                        do {
                            let account = try queryOperation.extractNoCancellableResultData()

                            let displayAddress = DisplayAddress(
                                address: payoutAddress,
                                username: account?.username ?? ""
                            )

                            let result: RewardDestination = .payout(account: displayAddress)

                            self.presenter.didReceiveRewardDestination(result: .success(result))
                        } catch {
                            self.presenter.didReceiveRewardDestination(result: .failure(error))
                        }
                    }
                }

                operationManager.enqueue(operations: [queryOperation], in: .transient)
            }
        } catch {
            logger?.error("Did receive reward destination error: \(error)")
        }
    }

    private func createFeeOperationWrapper() -> CompoundOperationWrapper<Decimal>? {
        guard let batches = batches,
              let firstBatch = batches.first,
              let lastBatch = batches.last,
              let firstFeeClosure = createExtrinsicBuilderClosure(for: firstBatch),
              let lastFeeClosure = createExtrinsicBuilderClosure(for: lastBatch)
        else { return nil }

        let firstFeeOperation = extrinsicOperationFactory.estimateFeeOperation(firstFeeClosure)
        let lastFeeOperation = extrinsicOperationFactory.estimateFeeOperation(lastFeeClosure)

        let dependencies = firstFeeOperation.allOperations + lastFeeOperation.allOperations

        let mergeOperation = ClosureOperation<Decimal> {
            let dispatchInfo = try lastFeeOperation.targetOperation.extractNoCancellableResultData()

            var fee = BigUInt(dispatchInfo.fee).map {
                Decimal.fromSubstrateAmount($0, precision: self.chain.addressType.precision) ?? 0.0
            } ?? 0.0

            if batches.count > 1 {
                let firstBatchDispatchInfo = try firstFeeOperation.targetOperation.extractNoCancellableResultData()
                let firstBatchFee = BigUInt(firstBatchDispatchInfo.fee).map {
                    Decimal.fromSubstrateAmount($0, precision: self.chain.addressType.precision) ?? 0.0
                } ?? 0.0

                fee += firstBatchFee * Decimal(batches.count - 1)
            }

            return fee
        }

        mergeOperation.addDependency(firstFeeOperation.targetOperation)
        mergeOperation.addDependency(lastFeeOperation.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: dependencies
        )
    }

    private func createBatchesOperationWrapper() -> CompoundOperationWrapper<[Batch]>? {
        guard let firstPayout = payouts.first,
              let feeClosure = createExtrinsicBuilderClosure(for: [firstPayout])
        else { return nil }

        let blockWeightsOperation = createBlockWeightsOperation()
        let feeOperation = extrinsicOperationFactory.estimateFeeOperation(feeClosure)

        let batchesOperationWrapper = ClosureOperation<[Batch]> {
            let blockWeights = try blockWeightsOperation.extractNoCancellableResultData()
            let fee = try feeOperation.targetOperation.extractNoCancellableResultData()

            let batchSize = Int(Double(blockWeights.maxBlock) / Double(fee.weight) * 0.64)
            let batches = stride(from: 0, to: self.payouts.count, by: batchSize).map {
                Array(self.payouts[$0 ..< Swift.min($0 + batchSize, self.payouts.count)])
            }

            return batches
        }

        batchesOperationWrapper.addDependency(blockWeightsOperation)
        batchesOperationWrapper.addDependency(feeOperation.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: batchesOperationWrapper,
            dependencies: [blockWeightsOperation] +
                blockWeightsOperation.dependencies +
                feeOperation.allOperations
        )
    }

    private func createBlockWeightsOperation() -> BaseOperation<BlockWeights> {
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

        return blockWeightsOperation
    }

    private func generateBatches(completion closure: @escaping () -> ()) {
        guard let batchesOperation = createBatchesOperationWrapper() else {
            return
        }

        batchesOperation.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    self?.batches = try batchesOperation.targetOperation.extractNoCancellableResultData()
                    closure()
                } catch {
                    self?.presenter.didReceiveFee(result: .failure(error))
                }
            }
        }

        operationManager.enqueue(operations: batchesOperation.allOperations, in: .transient)
    }
}

// MARK: - StakingPayoutConfirmationInteractorInputProtocol

extension StakingPayoutConfirmationInteractor: StakingPayoutConfirmationInteractorInputProtocol {
    func setup() {
        generateBatches() { self.estimateFee() }

        stashItemProvider = subscribeToStashItemProvider(for: selectedAccount.address)
        balanceProvider = subscribeToAccountInfoProvider(
            for: selectedAccount.address,
            runtimeService: runtimeService
        )
        priceProvider = subscribeToPriceProvider(for: assetId)

        provideRewardAmount()
    }

    func submitPayout() {
        guard let batches = batches else { return }

        var txHashes: [String] = []

        presenter.didStartPayout()

        for index in 0 ..< batches.count {
            let batch = batches[index]
            guard let closure = createExtrinsicBuilderClosure(for: batch) else {
                presenter.didFailPayout(error: CommonError.undefined)
                return
            }

            extrinsicService.submit(
                closure,
                signer: signer,
                runningIn: .main,
                nonceShift: UInt32(index)
            ) { [weak self] result in
                switch result {
                case let .success(txHash):
                    txHashes.append(txHash)
                    if txHashes.count == batches.count {
                        self?.presenter.didCompletePayout(txHashes: txHashes)
                    }

                case let .failure(error):
                    self?.presenter.didFailPayout(error: error)
                }
            }
        }
    }

    func estimateFee() {
        guard let feeOperation = createFeeOperationWrapper() else {
            presenter.didReceiveFee(result: .failure(CommonError.undefined))
            return
        }

        feeOperation.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let fee = try feeOperation.targetOperation.extractNoCancellableResultData()
                    self?.presenter.didReceiveFee(result: .success(fee))
                } catch {
                    self?.presenter.didReceiveFee(result: .failure(error))
                }
            }
        }

        operationManager.enqueue(operations: feeOperation.allOperations, in: .transient)
    }
}

// MARK: - SingleValueProviderSubscriber, SingleValueSubscriptionHandler, AnyProviderAutoCleaning

extension StakingPayoutConfirmationInteractor: SingleValueProviderSubscriber,
    SingleValueSubscriptionHandler,
    AnyProviderAutoCleaning {
    func handlePrice(result: Result<PriceData?, Error>, for _: WalletAssetId) {
        presenter.didReceivePriceData(result: result)
    }

    func handleAccountInfo(result: Result<AccountInfo?, Error>, address _: AccountAddress) {
        presenter.didReceiveAccountInfo(result: result)
    }

    func handlePayee(result: Result<RewardDestinationArg?, Error>, address _: AccountAddress) {
        switch result {
        case let .success(payee):
            guard let payee = payee else {
                return
            }

            provideRewardDestination(with: payee)

        case let .failure(error):
            presenter.didReceiveRewardDestination(result: .failure(error))
        }
    }
}

// MARK: - SubstrateProviderSubscriber, SubstrateProviderSubscriptionHandler

extension StakingPayoutConfirmationInteractor: SubstrateProviderSubscriber,
    SubstrateProviderSubscriptionHandler {
    func handleStashItem(result: Result<StashItem?, Error>) {
        do {
            stashItem = try result.get()

            clear(dataProvider: &payeeProvider)

            if let stashItem = stashItem {
                payeeProvider = subscribeToPayeeProvider(
                    for: stashItem.stash,
                    runtimeService: runtimeService
                )
            } else {
                presenter.didReceiveRewardDestination(result: .success(nil))
            }
        } catch {
            presenter.didReceiveRewardDestination(result: .failure(error))
            logger?.error("Stash subscription item error: \(error)")
        }
    }
}
