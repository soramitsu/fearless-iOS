import Foundation
import FearlessUtils
import SoraKeystore
import RobinHood
import BigInt

protocol StakingUnbondConfirmParachainStrategyOutput: AnyObject {
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>)
    func didReceiveExistentialDeposit(result: Result<BigUInt, Error>)
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>)
    func didReceiveMinBonded(result: Result<BigUInt?, Error>)
    func didSubmitUnbonding(result: Result<String, Error>)
}

final class StakingUnbondConfirmParachainStrategy: AccountFetching, RuntimeConstantFetching {
    weak var output: StakingUnbondConfirmParachainStrategyOutput?
    let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    let operationManager: OperationManagerProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol
    let chainAsset: ChainAsset
    let wallet: MetaAccountModel
    let connection: JSONRPCEngine
    let keystore: KeystoreProtocol
    let extrinsicService: ExtrinsicServiceProtocol?
    let signingWrapper: SigningWrapperProtocol?

    init(
        output: StakingUnbondConfirmParachainStrategyOutput?,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        operationManager: OperationManagerProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        connection: JSONRPCEngine,
        keystore: KeystoreProtocol,
        extrinsicService: ExtrinsicServiceProtocol?,
        signingWrapper: SigningWrapperProtocol?
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
    }

    private var minBondedProvider: AnyDataProvider<DecodedBigUInt>?
    private var accountInfoProvider: AnyDataProvider<DecodedAccountInfo>?
    private var nominationProvider: AnyDataProvider<DecodedNomination>?
    private var priceProvider: AnySingleValueProvider<PriceData>?

    private lazy var callFactory = SubstrateCallFactory()
}

extension StakingUnbondConfirmParachainStrategy: StakingUnbondConfirmStrategy {
    func setup() {
        if let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId {
            accountInfoSubscriptionAdapter.subscribe(
                chain: chainAsset.chain,
                accountId: accountId,
                handler: self
            )
        }

        // TODO: fetch min bond

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
        }
    }
}

extension StakingUnbondConfirmParachainStrategy: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(result: Result<AccountInfo?, Error>, accountId _: AccountId, chainId _: ChainModel.Id) {
        output?.didReceiveAccountInfo(result: result)
    }
}

extension StakingUnbondConfirmParachainStrategy: AnyProviderAutoCleaning {}

extension StakingUnbondConfirmParachainStrategy: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        output?.didReceiveFee(result: result)
    }
}
