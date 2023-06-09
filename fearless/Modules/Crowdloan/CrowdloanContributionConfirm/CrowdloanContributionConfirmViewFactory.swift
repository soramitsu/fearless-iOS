import Foundation
import SoraFoundation
import SoraKeystore
import RobinHood
import SSFModels

struct CrowdloanContributionConfirmViewFactory {
    static func createView(
        with paraId: ParaId,
        inputAmount: Decimal,
        bonusService: CrowdloanBonusServiceProtocol?,
        state: CrowdloanSharedState
    ) -> CrowdloanContributionConfirmViewProtocol? {
        guard
            let selectedAccount = SelectedWalletSettings.shared.value,
            let chain = state.settings.value,
            let asset = chain.utilityAssets().first,
            let interactor = createInteractor(
                for: paraId,
                chainAsset: ChainAsset(chain: chain, asset: asset),
                bonusService: bonusService,
                state: state
            ) else {
            return nil
        }

        let wireframe = CrowdloanContributionConfirmWireframe()

        let assetInfo = asset.displayInfo(with: chain.icon)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            selectedMetaAccount: selectedAccount
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

        let presenter = CrowdloanContributionConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            balanceViewModelFactory: balanceViewModelFactory,
            contributionViewModelFactory: contributionViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            inputAmount: inputAmount,
            bonusRate: bonusService?.bonusRate,
            assetInfo: assetInfo,
            localizationManager: localizationManager,
            logger: Logger.shared,
            chainAsset: ChainAsset(chain: chain, asset: asset)
        )

        let view = CrowdloanContributionConfirmVC(
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
        bonusService: CrowdloanBonusServiceProtocol?,
        state: CrowdloanSharedState
    ) -> CrowdloanContributionConfirmInteractor? {
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

        let keystore = Keychain()
        let signingWrapper = SigningWrapper(
            keystore: keystore,
            metaId: selectedMetaAccount.metaId,
            accountResponse: accountResponse
        )

        let existentialDepositService = ExistentialDepositService(
            operationManager: operationManager,
            chainRegistry: chainRegistry,
            chainId: chainAsset.chain.chainId
        )

        let callFactory = SubstrateCallFactoryAssembly.createCallFactory(for: runtimeService.runtimeSpecVersion)

        return CrowdloanContributionConfirmInteractor(
            paraId: paraId,
            selectedMetaAccount: selectedMetaAccount,
            chainAsset: chainAsset,
            runtimeService: runtimeService,
            feeProxy: feeProxy,
            extrinsicService: extrinsicService,
            crowdloanLocalSubscriptionFactory: state.crowdloanLocalSubscriptionFactory,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            jsonLocalSubscriptionFactory: JsonDataProviderFactory.shared,
            signingWrapper: signingWrapper,
            bonusService: bonusService,
            operationManager: operationManager,
            existentialDepositService: existentialDepositService,
            callFactory: callFactory
        )
    }
}
