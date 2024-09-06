import UIKit
import SoraFoundation
import SSFModels
import SSFUtils
import SoraKeystore

final class ClaimCrowdloanRewardsAssembly {
    static func configureModule(wallet: MetaAccountModel, chainAsset: ChainAsset) -> ClaimCrowdloanRewardsModuleCreationResult? {
        let localizationManager = LocalizationManager.shared
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId),
            let accountResponse = wallet.fetch(for: chainAsset.chain.accountRequest())
        else {
            return nil
        }

        let callFactory = SubstrateCallFactoryDefault(runtimeService: runtimeService)
        let operationManager = OperationManagerFacade.sharedManager
        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )
        let crowdloanOperationFactory = CrowdloanOperationFactory(
            requestOperationFactory: storageRequestFactory,
            operationManager: operationManager,
            chainRegistry: chainRegistry
        )
        let feeProxy = ExtrinsicFeeProxy()
        let extrinsicService = ExtrinsicService(
            accountId: accountResponse.accountId,
            chainFormat: chainAsset.chain.chainFormat,
            cryptoType: accountResponse.cryptoType,
            runtimeRegistry: runtimeService,
            engine: connection,
            operationManager: operationManager
        )
        let signer = SigningWrapper(
            keystore: Keychain(),
            metaId: wallet.metaId,
            accountResponse: accountResponse
        )
        let storageRequestPerformer = StorageRequestPerformerDefault(
            runtimeService: runtimeService,
            connection: connection
        )
        let substrateRepositoryFactory = SubstrateRepositoryFactory(
            storageFacade: UserDataStorageFacade.shared
        )
        let accountInfoRepository = substrateRepositoryFactory.createAccountInfoStorageItemRepository()
        let accountInfoFetcher = AccountInfoFetching(
            accountInfoRepository: accountInfoRepository,
            chainRegistry: chainRegistry,
            operationQueue: OperationQueue()
        )
        let interactor = ClaimCrowdloanRewardsInteractor(
            callFactory: callFactory,
            wallet: wallet,
            chainAsset: chainAsset,
            crowdloanOperationFactory: crowdloanOperationFactory,
            operationQueue: OperationQueue(),
            feeProxy: feeProxy,
            extrinsicService: extrinsicService,
            signer: signer,
            chainRegistry: chainRegistry,
            storageRequestPerformer: storageRequestPerformer,
            accountInfoFetcher: accountInfoFetcher
        )
        let router = ClaimCrowdloanRewardsRouter()

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            selectedMetaAccount: wallet,
            chainAsset: chainAsset
        )
        let viewModelFactory = ClaimCrowdloanRewardViewModelFactory(
            balanceViewModelFactory: balanceViewModelFactory,
            chainAsset: chainAsset
        )
        let presenter = ClaimCrowdloanRewardsPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager,
            logger: Logger.shared,
            chainAsset: chainAsset,
            balanceViewModelFactory: balanceViewModelFactory,
            viewModelFactory: viewModelFactory,
            wallet: wallet
        )

        let view = ClaimCrowdloanRewardsViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
