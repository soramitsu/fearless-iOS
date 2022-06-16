import Foundation
import FearlessUtils
import RobinHood
import BigInt

protocol StakingUnbondSetupParachainStrategyOutput: AnyObject {
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>)
    func didReceiveBondingDuration(result: Result<UInt32, Error>)
    func didReceiveExistentialDeposit(result: Result<BigUInt, Error>)
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>)
}

final class StakingUnbondSetupParachainStrategy: RuntimeConstantFetching, AccountFetching {
    init(
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        operationManager: OperationManagerProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        connection: JSONRPCEngine,
        output: StakingUnbondSetupParachainStrategyOutput?,
        extrinsicService: ExtrinsicServiceProtocol?
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
    }

    let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol

    private let runtimeService: RuntimeCodingServiceProtocol
    private let operationManager: OperationManagerProtocol
    private let feeProxy: ExtrinsicFeeProxyProtocol
    private let wallet: MetaAccountModel
    private let chainAsset: ChainAsset
    private let connection: JSONRPCEngine
    private weak var output: StakingUnbondSetupParachainStrategyOutput?
    private lazy var callFactory = SubstrateCallFactory()

    private var accountInfoProvider: AnyDataProvider<DecodedAccountInfo>?
    private var extrinsicService: ExtrinsicServiceProtocol?
}

extension StakingUnbondSetupParachainStrategy: StakingUnbondSetupStrategy {
    func estimateFee(builderClosure: ExtrinsicBuilderClosure?) {
        guard let builderClosure = builderClosure,
              let extrinsicService = extrinsicService,
              let amount = StakingConstants.maxAmount.toSubstrateAmount(
                  precision: Int16(chainAsset.asset.precision)
              ) else {
            return
        }

        let unbondCall = callFactory.unbond(amount: amount)

        feeProxy.estimateFee(
            using: extrinsicService,
            reuseIdentifier: unbondCall.callName,
            setupBy: builderClosure
        )
    }

    func setup() {
        if let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId {
            accountInfoSubscriptionAdapter.subscribe(
                chain: chainAsset.chain,
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
}

extension StakingUnbondSetupParachainStrategy: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {
        output?.didReceiveAccountInfo(result: result)
    }
}

extension StakingUnbondSetupParachainStrategy: AnyProviderAutoCleaning {}

extension StakingUnbondSetupParachainStrategy: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        output?.didReceiveFee(result: result)
    }
}
