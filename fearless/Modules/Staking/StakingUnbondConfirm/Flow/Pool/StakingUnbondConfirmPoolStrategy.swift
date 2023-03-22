import Foundation
import FearlessUtils
import SoraKeystore
import RobinHood
import BigInt

protocol StakingUnbondConfirmPoolStrategyOutput: AnyObject {
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>)
    func didReceiveExistentialDeposit(result: Result<BigUInt, Error>)
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>)
    func didReceiveMinBonded(result: Result<BigUInt?, Error>)
    func didSubmitUnbonding(result: Result<String, Error>)
    func didReceive(stakeInfo: StakingPoolMember?)
    func didReceive(error: Error)
}

final class StakingUnbondConfirmPoolStrategy: AccountFetching, RuntimeConstantFetching {
    weak var output: StakingUnbondConfirmPoolStrategyOutput?
    private let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    private let runtimeService: RuntimeCodingServiceProtocol
    private let operationManager: OperationManagerProtocol
    private let feeProxy: ExtrinsicFeeProxyProtocol
    private let chainAsset: ChainAsset
    private let wallet: MetaAccountModel
    private let connection: JSONRPCEngine
    private let keystore: KeystoreProtocol
    private let extrinsicService: ExtrinsicServiceProtocol?
    private let signingWrapper: SigningWrapperProtocol?
    private let eventCenter: EventCenterProtocol
    private var minBondedProvider: AnyDataProvider<DecodedBigUInt>?
    private var accountInfoProvider: AnyDataProvider<DecodedAccountInfo>?
    private var nominationProvider: AnyDataProvider<DecodedNomination>?
    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var poolMemberProvider: AnyDataProvider<DecodedPoolMember>?
    private let callFactory: SubstrateCallFactoryProtocol
    private(set) var stakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol

    init(
        output: StakingUnbondConfirmPoolStrategyOutput?,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        operationManager: OperationManagerProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        connection: JSONRPCEngine,
        keystore: KeystoreProtocol,
        extrinsicService: ExtrinsicServiceProtocol?,
        signingWrapper: SigningWrapperProtocol?,
        eventCenter: EventCenterProtocol,
        stakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol,
        callFactory: SubstrateCallFactoryProtocol
    ) {
        self.output = output
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.runtimeService = runtimeService
        self.operationManager = operationManager
        self.feeProxy = feeProxy
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.connection = connection
        self.keystore = keystore
        self.extrinsicService = extrinsicService
        self.signingWrapper = signingWrapper
        self.eventCenter = eventCenter
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.callFactory = callFactory
    }
}

extension StakingUnbondConfirmPoolStrategy: StakingUnbondConfirmStrategy {
    func setup() {
        if let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId {
            accountInfoSubscriptionAdapter.subscribe(
                chainAsset: chainAsset,
                accountId: accountId,
                handler: self
            )

            poolMemberProvider = subscribeToPoolMembers(for: accountId, chainAsset: chainAsset)
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

    func estimateFee(builderClosure: ExtrinsicBuilderClosure?, reuseIdentifier: String?) {
        guard let extrinsicService = extrinsicService,
              let builderClosure = builderClosure,
              let reuseIdentifier = reuseIdentifier else {
            output?.didReceiveFee(result: .failure(CommonError.undefined))
            return
        }

        feeProxy.estimateFee(
            using: extrinsicService,
            reuseIdentifier: reuseIdentifier,
            setupBy: builderClosure
        )
    }

    func submit(builderClosure: ExtrinsicBuilderClosure?) {
        guard
            let extrinsicService = extrinsicService,
            let signingWrapper = signingWrapper,
            let builderClosure = builderClosure else {
            output?.didSubmitUnbonding(result: .failure(CommonError.undefined))
            return
        }

        extrinsicService.submit(
            builderClosure,
            signer: signingWrapper,
            runningIn: .main
        ) { [weak self] result in
            self?.output?.didSubmitUnbonding(result: result)

            self?.eventCenter.notify(with: StakingUpdatedEvent())
        }
    }
}

extension StakingUnbondConfirmPoolStrategy: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(result: Result<AccountInfo?, Error>, accountId _: AccountId, chainAsset _: ChainAsset) {
        output?.didReceiveAccountInfo(result: result)
    }
}

extension StakingUnbondConfirmPoolStrategy: AnyProviderAutoCleaning {}

extension StakingUnbondConfirmPoolStrategy: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        output?.didReceiveFee(result: result)
    }
}

extension StakingUnbondConfirmPoolStrategy: RelaychainStakingLocalStorageSubscriber, RelaychainStakingLocalSubscriptionHandler {
    func handlePoolMember(
        result: Result<StakingPoolMember?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {
        switch result {
        case let .success(poolMember):
            output?.didReceive(stakeInfo: poolMember)
        case let .failure(error):
            output?.didReceive(error: error)
        }
    }
}
