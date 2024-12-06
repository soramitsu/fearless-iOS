import UIKit
import Web3
import SoraFoundation
import SSFModels
import SSFNetwork
import SoraKeystore

final class BridgeListAssembly {
    static func configureModule(
        sourceChainAsset: ChainAsset,
        destinationChainAsset: ChainAsset,
        amount: String,
        wallet: MetaAccountModel,
        moduleOutput: BridgeListModuleOutput?,
        selectedSort: UInt8
    ) -> BridgeListModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let networkWorker = NetworkWorkerImpl()
        let requestSigner = OKXDexRequestSigner()
        let okxService = OKXDexAggregatorServiceImpl(
            networkWorker: networkWorker,
            signer: requestSigner
        )
        let assetFetching = buildAssetFetching(flow: .okxSource)
        guard
            let eth = try? EthereumNodeFetching().getHttps(for: sourceChainAsset.chain),
            let accountResponse = wallet.fetch(for: sourceChainAsset.chain.accountRequest()),
            let senderAddress = accountResponse.toAddress(),
            let privateKey = try? fetchSecretKey(for: sourceChainAsset.chain, accountResponse: accountResponse, wallet: wallet),
            let ethereumPrivateKey = try? EthereumPrivateKey(privateKey: privateKey.bytes)
        else {
            return nil
        }
        let swapService = OKXEthereumSwapServiceImpl(
            privateKey: ethereumPrivateKey,
            senderAddress: senderAddress,
            eth: eth
        )
        let interactor = BridgeListInteractor(
            okxService: okxService,
            sourceChainAsset: sourceChainAsset,
            destinationChainAsset: destinationChainAsset,
            amount: amount,
            wallet: wallet,
            assetFetching: assetFetching,
            okxSwapService: swapService
        )
        let router = BridgeListRouter()

        let presenter = BridgeListPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager,
            sourceChainAsset: sourceChainAsset,
            destinationChainAsset: destinationChainAsset,
            viewModelFactory: BridgeListViewModelFactoryImpl(wallet: wallet),
            selectedSort: selectedSort
        )

        let view = BridgeListViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        presenter.moduleOutput = moduleOutput

        return (view, presenter)
    }

    private static func buildAssetFetching(flow: MultichainChainFetchingFlow) -> MultichainAssetFetching {
        let networkWorker = NetworkWorkerImpl()
        let okxService = OKXDexAggregatorServiceImpl(networkWorker: networkWorker, signer: OKXDexRequestSigner())

        switch flow {
        case let .okxDestination(sourceChainId):
            return OKXMultichainAssetFetching(okxService: okxService, sourceChainId: sourceChainId)
        case .okxSource:
            return OKXMultichainAssetFetching(okxService: okxService, sourceChainId: nil)
        case .preset:
            return OKXMultichainAssetFetching(okxService: okxService, sourceChainId: nil)
        }
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
