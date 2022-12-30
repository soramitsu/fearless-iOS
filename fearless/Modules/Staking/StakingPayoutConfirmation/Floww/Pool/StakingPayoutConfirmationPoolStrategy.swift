import Foundation
import RobinHood
import BigInt

protocol StakingPayoutConfirmationPoolStrategyOutput {
    func didRecieve(account: ChainAccountResponse, rewardAmount: Decimal)
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>)
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>)
    func didStartPayout()
    func didCompletePayout(result: SubmitExtrinsicResult)
    func didFailPayout(error: Error)
}

final class StakingPayoutConfirmationPoolStrategy: AccountFetching {
    private let rewardAmount: Decimal
    private let extrinsicOperationFactory: ExtrinsicOperationFactoryProtocol
    private let extrinsicService: ExtrinsicServiceProtocol
    private let runtimeService: RuntimeCodingServiceProtocol
    private let signer: SigningWrapperProtocol
    private let feeProxy: ExtrinsicFeeProxyProtocol

    let stakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol
    let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol

    private let operationManager: OperationManagerProtocol
    private let logger: LoggerProtocol?
    private let chainAsset: ChainAsset
    private let wallet: MetaAccountModel
    private let output: StakingPayoutConfirmationPoolStrategyOutput?

    private var balanceProvider: AnyDataProvider<DecodedAccountInfo>?

    init(
        rewardAmount: Decimal,
        stakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        extrinsicOperationFactory: ExtrinsicOperationFactoryProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        signer: SigningWrapperProtocol,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol? = nil,
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        output: StakingPayoutConfirmationPoolStrategyOutput?,
        feeProxy: ExtrinsicFeeProxyProtocol
    ) {
        self.rewardAmount = rewardAmount
        self.extrinsicOperationFactory = extrinsicOperationFactory
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.extrinsicService = extrinsicService
        self.runtimeService = runtimeService
        self.signer = signer
        self.operationManager = operationManager
        self.logger = logger
        self.wallet = wallet
        self.chainAsset = chainAsset
        self.output = output
        self.feeProxy = feeProxy
    }
}

extension StakingPayoutConfirmationPoolStrategy: StakingPayoutConfirmationStrategy {
    func submitPayout(builderClosure: ExtrinsicBuilderClosure?) {
        guard let builderClosure = builderClosure else {
            return
        }

        output?.didStartPayout()

        extrinsicService.submit(
            builderClosure,
            signer: signer,
            runningIn: .main
        ) { [weak self] result in
            do {
                self?.output?.didCompletePayout(result: result)
            } catch {
                self?.output?.didFailPayout(error: error)
            }
        }
    }

    func setup() {
        if let account = wallet.fetch(for: chainAsset.chain.accountRequest()) {
            output?.didRecieve(account: account, rewardAmount: rewardAmount)
        }

        if let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId {
            accountInfoSubscriptionAdapter.subscribe(
                chainAsset: chainAsset,
                accountId: accountId,
                handler: self
            )
        }

        feeProxy.delegate = self
    }

    func estimateFee(builderClosure: ExtrinsicBuilderClosure?) {
        guard let builderClosure = builderClosure else {
            return
        }

        feeProxy.estimateFee(
            using: extrinsicService,
            reuseIdentifier: "",
            setupBy: builderClosure
        )
    }
}

extension StakingPayoutConfirmationPoolStrategy: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(result: Result<AccountInfo?, Error>, accountId _: AccountId, chainAsset _: ChainAsset) {
        output?.didReceiveAccountInfo(result: result)
    }
}

extension StakingPayoutConfirmationPoolStrategy: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        output?.didReceiveFee(result: result)
    }
}
