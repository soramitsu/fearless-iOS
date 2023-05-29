import Foundation
import RobinHood
import SSFUtils
import BigInt

protocol StakingBondMorePoolStrategyOutput: AnyObject {
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>)
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>)
    func didSetup()
    func didReceiveExistentialDeposit(result: Result<BigUInt, Error>)

    func extrinsicServiceUpdated()
}

final class StakingBondMorePoolStrategy {
    private var balanceProvider: AnyDataProvider<DecodedAccountInfo>?

    let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol

    private weak var output: StakingBondMorePoolStrategyOutput?
    private let chainAsset: ChainAsset
    private let wallet: MetaAccountModel
    private let connection: JSONRPCEngine
    private var extrinsicService: ExtrinsicServiceProtocol
    private let feeProxy: ExtrinsicFeeProxyProtocol
    private let runtimeService: RuntimeCodingServiceProtocol
    private let operationManager: OperationManagerProtocol
    private let existentialDepositService: ExistentialDepositServiceProtocol
    private let callFactory: SubstrateCallFactoryProtocol

    init(
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        output: StakingBondMorePoolStrategyOutput?,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        connection: JSONRPCEngine,
        extrinsicService: ExtrinsicServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        operationManager: OperationManagerProtocol,
        callFactory: SubstrateCallFactoryProtocol,
        existentialDepositService: ExistentialDepositServiceProtocol
    ) {
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.output = output
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.connection = connection
        self.extrinsicService = extrinsicService
        self.feeProxy = feeProxy
        self.runtimeService = runtimeService
        self.operationManager = operationManager
        self.callFactory = callFactory
        self.existentialDepositService = existentialDepositService

        self.feeProxy.delegate = self
    }
}

extension StakingBondMorePoolStrategy: StakingBondMoreStrategy {
    func estimateFee(builderClosure: ExtrinsicBuilderClosure?, reuseIdentifier: String?) {
        guard let reuseIdentifier = reuseIdentifier, let builderClosure = builderClosure else {
            return
        }

        feeProxy.estimateFee(using: extrinsicService, reuseIdentifier: reuseIdentifier, setupBy: builderClosure)
    }

    func setup() {
        if let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId {
            accountInfoSubscriptionAdapter.subscribe(
                chainAsset: chainAsset,
                accountId: accountId,
                handler: self
            )
        }

        existentialDepositService.fetchExistentialDeposit(
            chainAsset: chainAsset
        ) { [weak self] result in
            self?.output?.didReceiveExistentialDeposit(result: result)
        }

        output?.didSetup()
    }
}

extension StakingBondMorePoolStrategy: AnyProviderAutoCleaning {}

extension StakingBondMorePoolStrategy: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        output?.didReceiveFee(result: result)
    }
}

extension StakingBondMorePoolStrategy: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(result: Result<AccountInfo?, Error>, accountId _: AccountId, chainAsset _: ChainAsset) {
        output?.didReceiveAccountInfo(result: result)
    }
}
