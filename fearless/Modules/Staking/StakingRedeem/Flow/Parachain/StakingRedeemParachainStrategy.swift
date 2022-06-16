import Foundation
import RobinHood
import SoraKeystore
import FearlessUtils
import BigInt

protocol StakingRedeemParachainStrategyOutput: AnyObject {
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>)
    func didReceiveExistentialDeposit(result: Result<BigUInt, Error>)
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>)
    func didSubmitRedeeming(result: Result<String, Error>)
}

final class StakingRedeemParachainStrategy: RuntimeConstantFetching, AccountFetching {
    weak var output: StakingRedeemParachainStrategyOutput?
    let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    let operationManager: OperationManagerProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol
    let engine: JSONRPCEngine
    let chainAsset: ChainAsset
    let wallet: MetaAccountModel
    let keystore: KeystoreProtocol

    private var activeEraProvider: AnyDataProvider<DecodedActiveEra>?
    private var accountInfoProvider: AnyDataProvider<DecodedAccountInfo>?
    private var priceProvider: AnySingleValueProvider<PriceData>?

    private var extrinsicService: ExtrinsicServiceProtocol?
    private var signingWrapper: SigningWrapperProtocol?

    init(
        output: StakingRedeemParachainStrategyOutput?,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        extrinsicService: ExtrinsicServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        engine: JSONRPCEngine,
        operationManager: OperationManagerProtocol,
        keystore: KeystoreProtocol
    ) {
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.feeProxy = feeProxy
        self.extrinsicService = extrinsicService
        self.runtimeService = runtimeService
        self.operationManager = operationManager
        self.engine = engine
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.keystore = keystore
        self.output = output
    }
}

extension StakingRedeemParachainStrategy: StakingRedeemStrategy {
    func setup() {
        if let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId {
            accountInfoSubscriptionAdapter.subscribe(chain: chainAsset.chain, accountId: accountId, handler: self)
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
            output?.didSubmitRedeeming(result: .failure(CommonError.undefined))
            return
        }

        extrinsicService.submit(
            builderClosure,
            signer: signingWrapper,
            runningIn: .main
        ) { [weak self] result in
            self?.output?.didSubmitRedeeming(result: result)
        }
    }
}

extension StakingRedeemParachainStrategy: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(result: Result<AccountInfo?, Error>, accountId _: AccountId, chainId _: ChainModel.Id) {
        output?.didReceiveAccountInfo(result: result)
    }
}

extension StakingRedeemParachainStrategy: AnyProviderAutoCleaning {}

extension StakingRedeemParachainStrategy: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        output?.didReceiveFee(result: result)
    }
}
