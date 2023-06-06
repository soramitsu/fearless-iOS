import Foundation
import SoraKeystore
import SoraFoundation
import SSFModels

struct CrowdloanContributionSetupViewFactory {
    static func createView(
        for paraId: ParaId,
        state: CrowdloanSharedState
    ) -> CrowdloanContributionSetupViewProtocol? {
        guard
            let chain = state.settings.value,
            let asset = chain.utilityAssets().first,
            let interactor = createInteractor(
                for: paraId,
                chainAsset: ChainAsset(chain: chain, asset: asset),
                state: state
            ),
            let selectedMetaAccount = SelectedWalletSettings.shared.value
        else {
            return nil
        }

        let wireframe = CrowdloanContributionSetupWireframe(state: state)

        let assetInfo = asset.displayInfo(with: chain.icon)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            selectedMetaAccount: selectedMetaAccount
        )

        let localizationManager = LocalizationManager.shared

        let contributionViewModelFactory = CrowdloanContributionViewModelFactory(
            assetInfo: assetInfo,
            chainDateCalculator: ChainDateCalculator(),
            iconGenerator: UniversalIconGenerator(chain: chain)
        )

        let dataValidatingFactory = CrowdloanDataValidatingFactory(
            presentable: wireframe,
            assetInfo: assetInfo
        )

        let presenter = CrowdloanContributionSetupPresenter(
            interactor: interactor,
            wireframe: wireframe,
            balanceViewModelFactory: balanceViewModelFactory,
            contributionViewModelFactory: contributionViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            assetInfo: assetInfo,
            localizationManager: localizationManager,
            logger: Logger.shared,
            chainAsset: ChainAsset(chain: chain, asset: asset)
        )

        let view = CrowdloanContributionSetupViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter
        dataValidatingFactory.view = view

        return view
    }

    private static func createInteractor(
        for paraId: ParaId,
        chainAsset: ChainAsset,
        state: CrowdloanSharedState
    ) -> CrowdloanContributionSetupInteractor? {
        guard let selectedMetaAccount = SelectedWalletSettings.shared.value else {
            return nil
        }

        let operationManager = OperationManagerFacade.sharedManager
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId) else {
            return nil
        }

        guard let accountResponse = selectedMetaAccount.fetch(for: chainAsset.chain.accountRequest()) else {
            return nil
        }

        let extrinsicService = ExtrinsicService(
            accountId: accountResponse.accountId,
            chainFormat: chainAsset.chain.chainFormat,
            cryptoType: accountResponse.cryptoType,
            runtimeRegistry: runtimeService,
            engine: connection,
            operationManager: operationManager
        )

        let feeProxy = ExtrinsicFeeProxy()

        let priceLocalSubscriptionFactory = PriceProviderFactory(
            storageFacade: SubstrateDataStorageFacade.shared
        )

        let jsonLocalSubscriptionFactory = JsonDataProviderFactory(
            storageFacade: SubstrateDataStorageFacade.shared
        )

        let existentialDepositService = ExistentialDepositService(
            runtimeCodingService: runtimeService,
            operationManager: operationManager,
            engine: connection
        )

        let callFactory = SubstrateCallFactoryAssembly.createCallFactory(for: runtimeService.runtimeSpecVersion)

        return CrowdloanContributionSetupInteractor(
            paraId: paraId,
            selectedMetaAccount: selectedMetaAccount,
            chainAsset: chainAsset,
            runtimeService: runtimeService,
            feeProxy: feeProxy,
            extrinsicService: extrinsicService,
            crowdloanLocalSubscriptionFactory: state.crowdloanLocalSubscriptionFactory,
            accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapter(
                walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
                selectedMetaAccount: selectedMetaAccount
            ),
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            jsonLocalSubscriptionFactory: jsonLocalSubscriptionFactory,
            operationManager: operationManager,
            existentialDepositService: existentialDepositService,
            callFactory: callFactory
        )
    }
}
