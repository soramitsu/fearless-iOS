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

    private let extrinsicService: ExtrinsicServiceProtocol
    private let feeProxy: ExtrinsicFeeProxyProtocol
    private let runtimeService: RuntimeCodingServiceProtocol
    private let signer: SigningWrapperProtocol

    private let accountRepository: AnyDataProviderRepository<AccountItem>
    private let settings: SettingsManagerProtocol
    private let operationManager: OperationManagerProtocol
    private let logger: LoggerProtocol?
    private let payouts: [PayoutInfo]
    private let chain: Chain
    private let assetId: WalletAssetId

    private var blockLimit: UInt64?
    private var batches: [Batch]?
    private var totalFee: Decimal?

    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var balanceProvider: AnyDataProvider<DecodedAccountInfo>?
    private var stashItemProvider: StreamableProvider<StashItem>?
    private var stashControllerProvider: StreamableProvider<StashItem>?
    private var payeeProvider: AnyDataProvider<DecodedPayee>?

    weak var presenter: StakingPayoutConfirmationInteractorOutputProtocol!

    init(
        singleValueProviderFactory: SingleValueProviderFactoryProtocol,
        substrateProviderFactory: SubstrateDataProviderFactoryProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        signer: SigningWrapperProtocol,
        accountRepository: AnyDataProviderRepository<AccountItem>,
        operationManager: OperationManagerProtocol,
        settings: SettingsManagerProtocol,
        logger: LoggerProtocol? = nil,
        payouts: [PayoutInfo],
        chain: Chain,
        assetId: WalletAssetId
    ) {
        self.singleValueProviderFactory = singleValueProviderFactory
        self.substrateProviderFactory = substrateProviderFactory
        self.extrinsicService = extrinsicService
        self.feeProxy = feeProxy
        self.runtimeService = runtimeService
        self.signer = signer
        self.accountRepository = accountRepository
        self.operationManager = operationManager
        self.settings = settings
        self.logger = logger
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

    private func createExtrinsicBuilderClosure() -> ExtrinsicBuilderClosure? {
        let callFactory = SubstrateCallFactory()

        let closure: ExtrinsicBuilderClosure = { builder in
            try self.payouts.forEach { payout in
                let payoutCall = try callFactory.payout(
                    validatorId: payout.validator,
                    era: payout.era
                )

                _ = try builder.adding(call: payoutCall).with(nonce: 0123)
            }

            return builder
        }

        return closure
    }

    private func provideRewardAmount() {
        guard let account = settings.selectedAccount else { return }

        let rewardAmount = payouts.map(\.reward).reduce(0, +)

        presenter.didRecieve(
            account: account,
            rewardAmount: rewardAmount
        )
    }

    private func processBatches() {
        guard let firstPayout = payouts.first else { return }

        guard payouts.count > 1 else {
            batches = [payouts]
            estimateFee()
            return
        }

        estimateFee(for: [firstPayout], with: FeeType.elaborateBlockWeight.rawValue)
    }

    private func estimateFee(for batch: Batch, with identifier: String) {
        guard let closure = createExtrinsicBuilderClosure(for: batch) else {
            presenter.didReceiveFee(result: .failure(CommonError.undefined))
            return
        }

        feeProxy.estimateFee(
            using: extrinsicService,
            reuseIdentifier: identifier,
            setupBy: closure
        )
    }
}

// MARK: - StakingPayoutConfirmationInteractorInputProtocol

extension StakingPayoutConfirmationInteractor: StakingPayoutConfirmationInteractorInputProtocol {
    func setup() {
        guard let selectedAccountAddress = settings.selectedAccount?.address else {
            return
        }

        feeProxy.delegate = self

        createBatches()

        stashItemProvider = subscribeToStashItemProvider(for: selectedAccountAddress)
        balanceProvider = subscribeToAccountInfoProvider(
            for: selectedAccountAddress,
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
        guard let batches = batches,
              let firstBatch = batches.first,
              let lastBatch = batches.last else {
            presenter.didReceiveFee(result: .failure(CommonError.undefined))
            return
        }

        totalFee = nil

        if batches.count > 1 {
            estimateFee(
                for: firstBatch,
                with: FeeType.estimateFirstBlock.rawValue
            )
        } else { totalFee = 0 }

        estimateFee(for: lastBatch, with: FeeType.estimateLastBlock.rawValue)
    }

    func provideRewardDestination(for payoutAddress: AccountAddress) {
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

                    self.presenter.didReceiveRewardDestiination(result: .success(result))
                } catch {
                    self.presenter.didReceiveRewardDestiination(result: .failure(error))
                }
            }
        }

        operationManager.enqueue(operations: [queryOperation], in: .transient)
    }
}

// MARK: - RuntimeConstantFetching

extension StakingPayoutConfirmationInteractor: RuntimeConstantFetching {
    private func createBatches() {
        fetchCompoundConstant(
            for: .blockWeights,
            runtimeCodingService: runtimeService,
            operationManager: operationManager
        ) { [weak self] (result: Result<BlockWeights, Error>) in
            switch result {
            case let .failure(error):
                self?.presenter.didReceiveFee(result: .failure(error))

            case let .success(blockWeights):
                let blockLimitInterimResult = Double(blockWeights.maxBlock) * 0.64
                self?.blockLimit = UInt64(blockLimitInterimResult)
                self?.processBatches()
            }
        }
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
        presenter.didReceivePayee(result: result)
    }
}

// MARK: - SubstrateProviderSubscriber, SubstrateProviderSubscriptionHandler

extension StakingPayoutConfirmationInteractor: SubstrateProviderSubscriber,
    SubstrateProviderSubscriptionHandler {
    func handleStashItem(result: Result<StashItem?, Error>) {
        do {
            let stashItem = try result.get()

            clear(dataProvider: &payeeProvider)

            if let stashItem = stashItem {
                payeeProvider = subscribeToPayeeProvider(
                    for: stashItem.stash,
                    runtimeService: runtimeService
                )

                presenter.didReceiveStashItem(result: .success(stashItem))
            } else {
                presenter.didReceiveStashItem(result: .success(nil))
            }
        } catch {
            presenter.didReceiveStashItem(result: .failure(error))
        }
    }
}

// MARK: - RuntimeConstantFetching

extension StakingPayoutConfirmationInteractor: ExtrinsicFeeProxyDelegate {
    enum FeeType: String {
        case elaborateBlockWeight
        case estimateFirstBlock
        case estimateLastBlock
    }

    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for identifier: ExtrinsicFeeId) {
        switch result {
        case let .failure(error):
            presenter.didReceiveFee(result: .failure(error))

        case let .success(dispatchInfo):
            guard let feeType = FeeType(rawValue: identifier) else {
                presenter.didReceiveFee(result: .failure(CommonError.undefined))
                return
            }

            switch feeType {
            case .elaborateBlockWeight:
                guard let blockLimit = blockLimit else {
                    presenter.didReceiveFee(result: .failure(CommonError.undefined))
                    return
                }

                let weight = dispatchInfo.weight
                let batchSize = Int(blockLimit / weight)

                batches = stride(from: 0, to: payouts.count, by: batchSize).map {
                    Array(payouts[$0 ..< Swift.min($0 + batchSize, payouts.count)])
                }

                estimateFee()

            case .estimateFirstBlock:
                let fee = BigUInt(dispatchInfo.fee).map {
                    Decimal.fromSubstrateAmount($0, precision: chain.addressType.precision) ?? 0.0
                } ?? 0.0

                guard let batches = batches else { return }

                guard var totalFee = totalFee else {
                    self.totalFee = fee * Decimal(batches.count - 1)
                    return
                }

                totalFee += fee * Decimal(batches.count - 1)
                self.totalFee = totalFee
                presenter.didReceiveFee(result: .success(totalFee))

            case .estimateLastBlock:
                let fee = BigUInt(dispatchInfo.fee).map {
                    Decimal.fromSubstrateAmount($0, precision: chain.addressType.precision) ?? 0.0
                } ?? 0.0

                guard var totalFee = totalFee else {
                    self.totalFee = fee
                    return
                }

                totalFee += fee
                self.totalFee = totalFee
                presenter.didReceiveFee(result: .success(totalFee))
            }
        }
    }
}
