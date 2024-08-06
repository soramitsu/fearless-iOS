import Foundation
import RobinHood
import SSFUtils
import SoraKeystore
import SSFModels
import SSFRuntimeCodingService

protocol StakingRebondConfirmationParachainStrategyOutput: AnyObject {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>)
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>)
    func didSubmitRebonding(result: Result<String, Error>)
}

final class StakingRebondConfirmationParachainStrategy: AccountFetching {
    private let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    private let runtimeService: RuntimeCodingServiceProtocol
    private let operationManager: OperationManagerProtocol
    private let feeProxy: ExtrinsicFeeProxyProtocol
    private let chainAsset: ChainAsset
    private let keystore: KeystoreProtocol
    private let wallet: MetaAccountModel
    private let connection: JSONRPCEngine
    private let accountRepository: AnyDataProviderRepository<MetaAccountModel>
    weak var output: StakingRebondConfirmationParachainStrategyOutput?
    private var accountInfoProvider: AnyDataProvider<DecodedAccountInfo>?
    private var extrinsicService: ExtrinsicServiceProtocol?
    private var signingWrapper: SigningWrapperProtocol?

    init(
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        extrinsicService: ExtrinsicServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        operationManager: OperationManagerProtocol,
        keystore: KeystoreProtocol,
        connection: JSONRPCEngine,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        output: StakingRebondConfirmationParachainStrategyOutput?,
        signingWrapper: SigningWrapperProtocol
    ) {
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.extrinsicService = extrinsicService
        self.feeProxy = feeProxy
        self.runtimeService = runtimeService
        self.operationManager = operationManager
        self.chainAsset = chainAsset
        self.keystore = keystore
        self.connection = connection
        self.wallet = wallet
        self.accountRepository = accountRepository
        self.output = output
        self.signingWrapper = signingWrapper
    }
}

extension StakingRebondConfirmationParachainStrategy: StakingRebondConfirmationStrategy {
    func setup() {
        feeProxy.delegate = self
    }

    func submit(builderClosure: ExtrinsicBuilderClosure?) {
        guard let builderClosure = builderClosure, let signingWrapper = signingWrapper else {
            return
        }

        extrinsicService?.submit(
            builderClosure,
            signer: signingWrapper,
            runningIn: .main,
            completion: { [weak self] result in
                self?.output?.didSubmitRebonding(result: result)
            }
        )
    }

    func estimateFee(builderClosure: ExtrinsicBuilderClosure?, reuseIdentifier: String?) {
        guard let builderClosure = builderClosure,
              let extrinsicService = extrinsicService,
              let reuseIdentifier = reuseIdentifier else {
            return
        }

        feeProxy.estimateFee(
            using: extrinsicService,
            reuseIdentifier: reuseIdentifier,
            setupBy: builderClosure
        )
    }
}

extension StakingRebondConfirmationParachainStrategy: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(result: Result<AccountInfo?, Error>, accountId _: AccountId, chainAsset _: ChainAsset) {
        output?.didReceiveAccountInfo(result: result)
    }
}

extension StakingRebondConfirmationParachainStrategy: AnyProviderAutoCleaning {}

extension StakingRebondConfirmationParachainStrategy: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        output?.didReceiveFee(result: result)
    }
}
