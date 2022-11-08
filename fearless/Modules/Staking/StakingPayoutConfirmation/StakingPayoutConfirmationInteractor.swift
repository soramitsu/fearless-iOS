import Foundation
import SoraKeystore
import CommonWallet
import RobinHood
import IrohaCrypto
import BigInt

final class StakingPayoutConfirmationInteractor: AccountFetching {
    typealias Batch = [PayoutInfo]

    private let extrinsicOperationFactory: ExtrinsicOperationFactoryProtocol
    private let extrinsicService: ExtrinsicServiceProtocol
    private let runtimeService: RuntimeCodingServiceProtocol
    private let signer: SigningWrapperProtocol

    let stakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol
    let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol

    private let accountRepository: AnyDataProviderRepository<MetaAccountModel>
    private let operationManager: OperationManagerProtocol
    private let logger: LoggerProtocol?
    private let payouts: [PayoutInfo]
    private let chainAsset: ChainAsset
    private let selectedAccount: MetaAccountModel

    private var batches: [Batch]?

    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var balanceProvider: AnyDataProvider<DecodedAccountInfo>?
    private var stashItemProvider: StreamableProvider<StashItem>?
    private var stashControllerProvider: StreamableProvider<StashItem>?
    private var payeeProvider: AnyDataProvider<DecodedPayee>?

    private var stashItem: StashItem?

    weak var presenter: StakingPayoutConfirmationInteractorOutputProtocol!

    init(
        stakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        extrinsicOperationFactory: ExtrinsicOperationFactoryProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        signer: SigningWrapperProtocol,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol? = nil,
        selectedAccount: MetaAccountModel,
        payouts: [PayoutInfo],
        chainAsset: ChainAsset,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>
    ) {
        self.extrinsicOperationFactory = extrinsicOperationFactory
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.extrinsicService = extrinsicService
        self.runtimeService = runtimeService
        self.signer = signer
        self.operationManager = operationManager
        self.logger = logger
        self.selectedAccount = selectedAccount
        self.payouts = payouts
        self.chainAsset = chainAsset
        self.accountRepository = accountRepository
    }

    // MARK: - Private functions

    private func createExtrinsicBuilderClosure(for payouts: [PayoutInfo]) -> ExtrinsicBuilderIndexedClosure? {
        let callFactory = SubstrateCallFactory()

        let closure: ExtrinsicBuilderIndexedClosure = { [weak self] builder, _ in
            try payouts.forEach { payout in
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

        guard let account = selectedAccount.fetch(for: chainAsset.chain.accountRequest()) else {
            return
        }

        presenter.didRecieve(
            account: account,
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
                chainFormat: chainAsset.chain.chainFormat
            )

            switch rewardDestination {
            case .restake:
                presenter.didReceiveRewardDestination(result: .success(.restake))

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
                        self?.presenter.didReceiveRewardDestination(result: .success(destination))

                    case let .failure(error):
                        self?.presenter.didReceiveRewardDestination(result: .failure(error))
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
                return BigUInt(dispatchInfo.fee).map {
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

// MARK: - StakingPayoutConfirmationInteractorInputProtocol

extension StakingPayoutConfirmationInteractor: StakingPayoutConfirmationInteractorInputProtocol {
    func setup() {
        estimateFee()

        if let address = selectedAccount.fetch(for: chainAsset.chain.accountRequest())?.toAddress() {
            stashItemProvider = subscribeStashItemProvider(for: address)
        }

        if let accountId = selectedAccount.fetch(for: chainAsset.chain.accountRequest())?.accountId {
            accountInfoSubscriptionAdapter.subscribe(chainAsset: chainAsset, accountId: accountId, handler: self)
        }

        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId)
        }

        provideRewardAmount()
    }

    func submitPayout() {
        let payoutsUnwrapped = payouts
        guard !payoutsUnwrapped.isEmpty else { return }

        presenter.didStartPayout()

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

                self?.presenter.didCompletePayout(txHashes: txHashes)
            } catch {
                self?.presenter.didFailPayout(error: error)
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

extension StakingPayoutConfirmationInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        presenter.didReceivePriceData(result: result)
    }
}

extension StakingPayoutConfirmationInteractor: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(result: Result<AccountInfo?, Error>, accountId _: AccountId, chainAsset _: ChainAsset) {
        presenter.didReceiveAccountInfo(result: result)
    }
}

extension StakingPayoutConfirmationInteractor: RelaychainStakingLocalStorageSubscriber, RelaychainStakingLocalSubscriptionHandler {
    func handlePayee(result: Result<RewardDestinationArg?, Error>, accountId _: AccountId, chainId _: ChainModel.Id) {
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

    func handleStashItem(result: Result<StashItem?, Error>, for _: AccountAddress) {
        do {
            stashItem = try result.get()

            clear(dataProvider: &payeeProvider)

            let addressFactory = SS58AddressFactory()
            if let stashItem = stashItem,
               let accountId = try? addressFactory.accountId(fromAddress: stashItem.stash, type: chainAsset.chain.addressPrefix) {
                payeeProvider = subscribePayee(for: accountId, chainAsset: chainAsset)
            } else {
                presenter.didReceiveRewardDestination(result: .success(nil))
            }
        } catch {
            presenter.didReceiveRewardDestination(result: .failure(error))
            logger?.error("Stash subscription item error: \(error)")
        }
    }
}

// MARK: - SingleValueProviderSubscriber, SingleValueSubscriptionHandler, AnyProviderAutoCleaning

extension StakingPayoutConfirmationInteractor: AnyProviderAutoCleaning {}

// MARK: - SubstrateProviderSubscriber, SubstrateProviderSubscriptionHandler
