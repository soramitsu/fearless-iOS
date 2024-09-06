import UIKit
import SoraFoundation
import SoraKeystore
import RobinHood
import SSFModels
import SSFAccountManagmentStorage

final class PoolRolesConfirmAssembly {
    static func configureModule(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        poolId: String,
        roles: StakingPoolRoles
    ) -> PoolRolesConfirmModuleCreationResult? {
        let localizationManager = LocalizationManager.shared
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId),
            let accountResponse = wallet.fetch(for: chainAsset.chain.accountRequest())
        else {
            return nil
        }

        let operationManager = OperationManagerFacade.sharedManager

        let extrinsicService = ExtrinsicService(
            accountId: accountResponse.accountId,
            chainFormat: chainAsset.chain.chainFormat,
            cryptoType: accountResponse.cryptoType,
            runtimeRegistry: runtimeService,
            engine: connection,
            operationManager: operationManager
        )

        let feeProxy = ExtrinsicFeeProxy()
        let logger = Logger.shared

        let signingWrapper = SigningWrapper(
            keystore: Keychain(),
            metaId: wallet.metaId,
            accountResponse: accountResponse
        )

        let facade = UserDataStorageFacade.shared

        let mapper = MetaAccountMapper()

        let accountRepository: CoreDataRepository<MetaAccountModel, CDMetaAccount> = facade.createRepository(
            filter: nil,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        let callFactory = SubstrateCallFactoryDefault(runtimeService: runtimeService)

        let interactor = PoolRolesConfirmInteractor(
            extrinsicService: extrinsicService,
            feeProxy: feeProxy,
            poolId: poolId,
            roles: roles,
            signingWrapper: signingWrapper,
            chainAsset: chainAsset,
            accountRepository: AnyDataProviderRepository(accountRepository),
            operationManager: OperationManagerFacade.sharedManager,
            callFactory: callFactory
        )

        let router = PoolRolesConfirmRouter()

        let assetInfo = chainAsset.asset.displayInfo(with: chainAsset.chain.icon)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            selectedMetaAccount: wallet,
            chainAsset: chainAsset
        )

        let viewModelFactory = PoolRolesConfirmViewModelFactory(chainAsset: chainAsset)

        let presenter = PoolRolesConfirmPresenter(
            interactor: interactor,
            router: router,
            balanceViewModelFactory: balanceViewModelFactory,
            viewModelFactory: viewModelFactory,
            localizationManager: localizationManager,
            roles: roles,
            chainAsset: chainAsset,
            wallet: wallet,
            logger: logger
        )

        let view = PoolRolesConfirmViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
