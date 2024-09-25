import UIKit
import SSFNetwork
import SoraFoundation
import SSFModels
import Web3
import SoraKeystore

final class CrossChainSwapConfirmAssembly {
    static func configureModule(
        swapFromChainAsset: ChainAsset,
        swapToChainAsset: ChainAsset,
        wallet: MetaAccountModel,
        swap: CrossChainSwap
    ) -> CrossChainSwapConfirmModuleCreationResult? {
        let localizationManager = LocalizationManager.shared
        let accountInfoSubscriptionAdapter = AccountInfoSubscriptionAdapter(
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            selectedMetaAccount: wallet
        )

        guard
            let eth = try? EthereumNodeFetching().getHttps(for: swapFromChainAsset.chain),
            let accountResponse = wallet.fetch(for: swapFromChainAsset.chain.accountRequest()),
            let senderAddress = accountResponse.toAddress(),
            let privateKey = try? fetchSecretKey(for: swapFromChainAsset.chain, accountResponse: accountResponse, wallet: wallet),
            let ethereumPrivateKey = try? EthereumPrivateKey(privateKey: privateKey.bytes)
        else {
            return nil
        }
        let networkWorker = NetworkWorkerImpl()
        let okxService = OKXDexAggregatorServiceImpl(networkWorker: networkWorker, signer: OKXDexRequestSigner())

        let swapService = OKXEthereumSwapServiceImpl(
            privateKey: ethereumPrivateKey,
            senderAddress: senderAddress,
            eth: eth
        )
        let interactor = CrossChainSwapConfirmInteractor(
            swap: swap,
            swapService: swapService,
            wallet: wallet,
            swapFromChainAsset: swapFromChainAsset,
            accountInfoSubscriptionAdapter: accountInfoSubscriptionAdapter,
            okxService: okxService
        )
        let router = CrossChainSwapConfirmRouter()
        let dataValidatingFactory = SendDataValidatingFactory(presentable: router)
        let viewModelFactory = CrossChainSwapConfirmViewModelFactoryImpl(wallet: wallet)
        let presenter = CrossChainSwapConfirmPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager,
            swapFromChainAsset: swapFromChainAsset,
            swapToChainAsset: swapToChainAsset,
            swap: swap,
            viewModelFactory: viewModelFactory,
            wallet: wallet,
            dataValidatingFactory: dataValidatingFactory
        )

        let view = CrossChainSwapConfirmViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        dataValidatingFactory.view = view

        return (view, presenter)
    }

    private static func fetchSecretKey(
        for chain: ChainModel,
        accountResponse: ChainAccountResponse,
        wallet: MetaAccountModel
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
