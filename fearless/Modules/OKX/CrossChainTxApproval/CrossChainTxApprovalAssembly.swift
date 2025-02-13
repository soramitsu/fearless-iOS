import UIKit
import SoraFoundation
import SSFModels
import SSFNetwork
import SoraKeystore
import Web3

final class CrossChainFundsPermissionAssembly {
    static func configureModule(
        mode: CrossChainFundsPermissionMode,
        crossChainSwapParameters: CrossChainSwapParameters
    ) -> CrossChainFundsPermissionModuleCreationResult? {
        let localizationManager = LocalizationManager.shared
            
        let substrateRepositoryFactory = SubstrateRepositoryFactory(
            storageFacade: UserDataStorageFacade.shared
        )
        let repository = SubstrateRepositoryFactory(
            storageFacade: UserDataStorageFacade.shared
        ).createAccountInfoStorageItemRepository()
        let ethereumBalanceRepositoryWrapper = BalanceRepositoryCacheWrapper(
            logger: Logger.shared,
            repository: repository,
            operationManager: OperationManagerFacade.sharedManager
        )
        let accountInfoRepository = substrateRepositoryFactory.createAccountInfoStorageItemRepository()
        let accountInfoFetching = AccountInfoFetching(
            accountInfoRepository: accountInfoRepository,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            operationQueue: OperationQueue()
        )
        let ethereumBalanceFetching = EthereumRemoteBalanceFetching(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            repositoryWrapper: ethereumBalanceRepositoryWrapper
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
        
        let interactor = CrossChainFundsPermissionInteractor(
            swapService: swapService,
            wallet: crossChainSwapParameters.wallet,
            swapFromChainAsset: crossChainSwapParameters.swapFromChainAsset,
            okxService: okxService,
            amount: crossChainSwapParameters.amount,
            swap: crossChainSwapParameters.swap,
            balanceFetching: ethereumBalanceFetching,
            accountInfoFetchingProvider: accountInfoFetching
        )
        let router = CrossChainFundsPermissionRouter()
        
        let balanceViewModelFactory = BalanceViewModelFactory(targetAssetInfo: crossChainSwapParameters.swapFromChainAsset.assetDisplayInfo, selectedMetaAccount: crossChainSwapParameters.wallet, chainAsset: crossChainSwapParameters.swapFromChainAsset)
        let feeBalanceViewModelFactory = crossChainSwapParameters.swapFromChainAsset.chain.utilityChainAssets().first.flatMap { BalanceViewModelFactory(targetAssetInfo: $0.assetDisplayInfo, selectedMetaAccount: crossChainSwapParameters.wallet, chainAsset: $0)}
        let viewModelFactory = CrossChainFundsPermissionViewModelFactory(balanceViewModelFactory: balanceViewModelFactory, amountFormatterFactory: AssetBalanceFormatterFactory())
        let dataValidatingFactory = SendDataValidatingFactory(presentable: router)
        let presenter = CrossChainFundsPermissionPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager,
            viewModelFactory: viewModelFactory,
            mode: mode,
            chainAsset: crossChainSwapParameters.swapFromChainAsset,
            wallet: crossChainSwapParameters.wallet,
            swap: crossChainSwapParameters.swap,
            feeBalanceViewModelFactory: feeBalanceViewModelFactory,
            crossChainSwapParameters: crossChainSwapParameters,
            dataValidatingFactory: dataValidatingFactory,
            logger: Logger.shared
        )
        
        let view = CrossChainFundsPermissionViewController(
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
