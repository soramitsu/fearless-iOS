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

final class CrossChainSwapConfirmInteractor {
    // MARK: - Private properties

    private weak var output: CrossChainSwapConfirmInteractorOutput?
    private let swap: CrossChainSwap
    private let swapService: OKXEthereumSwapService
    private let wallet: MetaAccountModel
    private let swapFromChainAsset: ChainAsset
    private let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    private let okxService: OKXDexAggregatorService

    init(
        swap: CrossChainSwap,
        swapService: OKXEthereumSwapService,
        wallet: MetaAccountModel,
        swapFromChainAsset: ChainAsset,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        okxService: OKXDexAggregatorService
    ) {
        self.swap = swap
        self.swapService = swapService
        self.wallet = wallet
        self.swapFromChainAsset = swapFromChainAsset
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.okxService = okxService
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

    private func fetchApproveTransaction() async throws -> OKXApproveTransaction {
        guard let amount = swap.fromAmount else {
            throw CrossChainSwapConfirmInteractorError.approveInvalidAmount
        }

        let fromTokensParameters = OKXDexAllTokensRequestParameters(chainId: swapFromChainAsset.chain.chainId)
        let fromTokens = try await okxService.fetchAllTokens(parameters: fromTokensParameters)

        guard
            let fromTokenAddress = fromTokens.data.first(where: { $0.tokenSymbol.lowercased() == swapFromChainAsset.asset.symbol.lowercased() })?.tokenContractAddress
        else {
            throw CrossChainSwapSetupInteractorError.cannotFindTokenAddress
        }
        let parameters = OKXDexApproveRequestParameters(chainId: swapFromChainAsset.chain.chainId, tokenContractAddress: fromTokenAddress, approveAmount: amount)
        let approveTransaction = try await okxService.fetchApproveTransactionInfo(parameters: parameters).data.first

        guard let approveTransaction else {
            throw CrossChainSwapConfirmInteractorError.invalidApproveTransactionResponse
        }

        return approveTransaction
    }

    private func sendApproveTransaction(approveTransaction: OKXApproveTransaction) async throws {
        guard let fromAmount = swap.fromAmount, let amount = BigUInt(string: fromAmount) else {
            return
        }

        guard let dexTokenApproveAddress = try await okxService.fetchAvailableChains().data.first(where: { swapFromChainAsset.chain.chainId == "\($0.chainId)" })?.dexTokenApproveAddress else {
            throw CrossChainSwapConfirmInteractorError.invalidApproveTransactionResponse
        }
        let allowance = try await swapService.getAllowance(dexTokenApproveAddress: dexTokenApproveAddress, chainAsset: swapFromChainAsset)

        guard allowance < amount else {
            return
        }

        _ = try await swapService.approve(
            approveTransaction: approveTransaction,
            chain: swapFromChainAsset.chain,
            chainAsset: swapFromChainAsset
        )
    }
}

// MARK: - CrossChainSwapConfirmInteractorInput

extension CrossChainSwapConfirmInteractor: CrossChainSwapConfirmInteractorInput {
    func setup(with output: CrossChainSwapConfirmInteractorOutput) {
        self.output = output
    }

    func confirmSwap() async throws {
        let approveTransaction = try await fetchApproveTransaction()
        do {
            try await sendApproveTransaction(approveTransaction: approveTransaction)
        } catch {
            print("Approve transaction error: ", error)
        }

        do {
            let response = try await swapService.swap(swap: swap, chain: swapFromChainAsset.chain)
            print("Response: ", response)
        } catch {
            print("Swap error: ", error)
        }
    }

    func estimateFee() async throws -> BigUInt {
        try await swapService.estimateFee(swap: swap)
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
