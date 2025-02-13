import UIKit
import SSFNetwork
import SoraFoundation
import SSFModels
import Web3
import SoraKeystore

final class CrossChainSwapConfirmAssembly {
    static func configureModule(
        crossChainSwapParameters: CrossChainSwapParameters,
        approveTxHash: String?
    ) -> CrossChainSwapConfirmModuleCreationResult? {
        let localizationManager = LocalizationManager.shared
        let accountInfoSubscriptionAdapter = AccountInfoSubscriptionAdapter(
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            selectedMetaAccount: crossChainSwapParameters.wallet
        )

        guard
            let eth = try? EthereumNodeFetching().getHttps(for: crossChainSwapParameters.swapFromChainAsset.chain),
            let accountResponse = crossChainSwapParameters.wallet.fetch(for: crossChainSwapParameters.swapFromChainAsset.chain.accountRequest()),
            let senderAddress = accountResponse.toAddress(),
            let privateKey = try? fetchSecretKey(for: crossChainSwapParameters.swapFromChainAsset.chain, accountResponse: accountResponse, wallet: crossChainSwapParameters.wallet),
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
        let dependencyContainer = CrossChainDependencyContainer(okxService: okxService, wallet: crossChainSwapParameters.wallet)

        let interactor = CrossChainSwapConfirmInteractor(
            swapService: swapService,
            wallet: crossChainSwapParameters.wallet,
            swapFromChainAsset: crossChainSwapParameters.swapFromChainAsset,
            accountInfoSubscriptionAdapter: accountInfoSubscriptionAdapter,
            okxService: okxService,
            amount: crossChainSwapParameters.amount,
            swap: crossChainSwapParameters.swap,
            dependencyContainer: dependencyContainer
        )
        let router = CrossChainSwapConfirmRouter()
        let dataValidatingFactory = SendDataValidatingFactory(presentable: router)
        let viewModelFactory = CrossChainSwapConfirmViewModelFactoryImpl(wallet: crossChainSwapParameters.wallet)
        let presenter = CrossChainSwapConfirmPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager,
            swapFromChainAsset: crossChainSwapParameters.swapFromChainAsset,
            swapToChainAsset: crossChainSwapParameters.swapToChainAsset,
            swap: crossChainSwapParameters.swap,
            viewModelFactory: viewModelFactory,
            wallet: crossChainSwapParameters.wallet,
            dataValidatingFactory: dataValidatingFactory,
            amount: crossChainSwapParameters.amount,
            selectedDexIds: crossChainSwapParameters.selectedDexIds,
            logger: Logger.shared,
            slippage: crossChainSwapParameters.slippage,
            approveTxHash: approveTxHash
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
