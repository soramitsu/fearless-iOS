import Foundation
import SSFUtils
import RobinHood
import BigInt
import SSFModels
import SSFRuntimeCodingService

protocol StakingUnbondSetupParachainStrategyOutput: AnyObject {
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>)
    func didReceiveBondingDuration(result: Result<UInt32, Error>)
    func didReceiveExistentialDeposit(result: Result<BigUInt, Error>)
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>)
    func didSetup()
    func didReceiveTopDelegations(delegations: [AccountAddress: ParachainStakingDelegations])
}

final class StakingUnbondSetupParachainStrategy: RuntimeConstantFetching, AccountFetching {
    private weak var output: StakingUnbondSetupParachainStrategyOutput?
    private let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    private let runtimeService: RuntimeCodingServiceProtocol
    private let operationManager: OperationManagerProtocol
    private let feeProxy: ExtrinsicFeeProxyProtocol
    private let wallet: MetaAccountModel
    private let chainAsset: ChainAsset
    private let connection: JSONRPCEngine
    private let operationFactory: ParachainCollatorOperationFactory
    private let candidate: ParachainStakingCandidateInfo
    private let delegation: ParachainStakingDelegation
    private var accountInfoProvider: AnyDataProvider<DecodedAccountInfo>?
    private var extrinsicService: ExtrinsicServiceProtocol?
    private let callFactory: SubstrateCallFactoryProtocol

    init(
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        operationManager: OperationManagerProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        connection: JSONRPCEngine,
        output: StakingUnbondSetupParachainStrategyOutput?,
        extrinsicService: ExtrinsicServiceProtocol?,
        operationFactory: ParachainCollatorOperationFactory,
        candidate: ParachainStakingCandidateInfo,
        delegation: ParachainStakingDelegation,
        callFactory: SubstrateCallFactoryProtocol
    ) {
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.runtimeService = runtimeService
        self.operationManager = operationManager
        self.feeProxy = feeProxy
        self.wallet = wallet
        self.chainAsset = chainAsset
        self.connection = connection
        self.output = output
        self.extrinsicService = extrinsicService
        self.operationFactory = operationFactory
        self.candidate = candidate
        self.delegation = delegation
        self.callFactory = callFactory
    }
}

extension StakingUnbondSetupParachainStrategy: StakingUnbondSetupStrategy {
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
        if let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId {
            accountInfoSubscriptionAdapter.subscribe(
                chainAsset: chainAsset,
                accountId: accountId,
                handler: self
            )
        }

        fetchConstant(
            for: .candidateBondLessDelay,
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

        requestCollatorsTopDelegations()
    }

    func estimateFee() {
        guard let extrinsicService = extrinsicService,
              let amount = StakingConstants.maxAmount.toSubstrateAmount(
                  precision: Int16(chainAsset.asset.precision)
              ) else {
            return
        }

        let unbondCall = callFactory.unbond(amount: amount)
        let setPayeeCall = callFactory.setPayee(for: .stash)
        let chillCall = callFactory.chill()

        feeProxy.estimateFee(using: extrinsicService, reuseIdentifier: unbondCall.callName) { builder in
            try builder.adding(call: chillCall).adding(call: unbondCall).adding(call: setPayeeCall)
        }
    }

    private func requestCollatorsTopDelegations() {
        let topDelegationsOperation = operationFactory.collatorTopDelegations { [unowned self] in
            [self.candidate.owner]
        }

        topDelegationsOperation.targetOperation.completionBlock = { [weak self] in
            do {
                let response = try topDelegationsOperation.targetOperation.extractNoCancellableResultData()

                guard let delegations = response else {
                    return
                }

                self?.output?.didReceiveTopDelegations(delegations: delegations)
            } catch {
                Logger.shared.error("StakingUnbondSetupParachainStrategy.requestCollatorsTopDelegations.error: \(error)")
            }
        }

        operationManager.enqueue(operations: topDelegationsOperation.allOperations, in: .transient)
    }
}

extension StakingUnbondSetupParachainStrategy: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(result: Result<AccountInfo?, Error>, accountId _: AccountId, chainAsset _: ChainAsset) {
        output?.didReceiveAccountInfo(result: result)
    }
}

extension StakingUnbondSetupParachainStrategy: AnyProviderAutoCleaning {}

extension StakingUnbondSetupParachainStrategy: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        output?.didReceiveFee(result: result)
    }
}
