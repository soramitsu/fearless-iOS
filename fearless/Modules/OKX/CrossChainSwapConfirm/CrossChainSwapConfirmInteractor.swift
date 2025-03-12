import UIKit
import Web3
import SSFModels
import SoraKeystore

enum CrossChainSwapConfirmInteractorError: Error {
    case approveInvalidAmount
    case invalidApproveTransactionResponse
}

protocol CrossChainSwapConfirmInteractorOutput: AnyObject {
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for chainAsset: ChainAsset)
}

final class CrossChainSwapConfirmInteractor: CrossChainBaseInteractor {
    // MARK: - Private properties

    private weak var output: CrossChainSwapConfirmInteractorOutput?
    private let swapService: OKXEthereumSwapService
    private let wallet: MetaAccountModel
    private let swapFromChainAsset: ChainAsset
    private let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    private let okxService: OKXDexAggregatorService
    private let amount: String
    private let swap: CrossChainSwap
    

    init(
        swapService: OKXEthereumSwapService,
        wallet: MetaAccountModel,
        swapFromChainAsset: ChainAsset,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        okxService: OKXDexAggregatorService,
        amount: String,
        swap: CrossChainSwap,
        dependencyContainer: CrossChainDependencyContainer,
        assetFetching: MultichainAssetFetching
    ) {
        self.swapService = swapService
        self.wallet = wallet
        self.swapFromChainAsset = swapFromChainAsset
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.okxService = okxService
        self.amount = amount
        self.swap = swap

        super.init(
            dependencyContainer: dependencyContainer,
            assetFetching: assetFetching
        )
    }

    private func fetchSecretKey(
        for chain: ChainModel,
        accountResponse: ChainAccountResponse
    ) throws -> Data {
        let accountId = accountResponse.isChainAccount ? accountResponse.accountId : nil
        let tag: String = chain.isEthereumBased
            ? KeystoreTagV2.ethereumSecretKeyTagForMetaId(wallet.metaId, accountId: accountId)
            : KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId, accountId: accountId)

        let keystore = Keychain()
        let secretKey = try keystore.fetchKey(for: tag)
        return secretKey
    }
}

// MARK: - CrossChainSwapConfirmInteractorInput

extension CrossChainSwapConfirmInteractor: CrossChainSwapConfirmInteractorInput {
    func setup(with output: CrossChainSwapConfirmInteractorOutput) {
        self.output = output
    }
    
    func checkTransactionSucceed(approveTxHash: String) async throws -> Bool {
        return try await swapService.isTransactionExists(txHash: approveTxHash)
    }

    func confirmSwap(tx: CrossChainTx) async throws -> String {
        let response = try await swapService.swap(swap: tx, chainAsset: swapFromChainAsset)
        return response
    }

    func estimateFee(tx: CrossChainTx) async throws -> BigUInt {
        try await swapService.estimateFee(swap: tx)
    }

    func subscribeOnBalance(for chainAssets: [ChainAsset]) {
        accountInfoSubscriptionAdapter.subscribe(
            chainsAssets: chainAssets,
            handler: self,
            deliveryOn: .main
        )
    }
}

// MARK: - AccountInfoSubscriptionAdapterHandler

extension CrossChainSwapConfirmInteractor: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId _: AccountId,
        chainAsset: ChainAsset
    ) {
        output?.didReceiveAccountInfo(result: result, for: chainAsset)
    }
}
