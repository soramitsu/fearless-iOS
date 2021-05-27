import Foundation
import SoraKeystore
import SoraFoundation

struct CrowdloanContributionSetupViewFactory {
    static func createView(for paraId: ParaId) -> CrowdloanContributionSetupViewProtocol? {
        let settings = SettingsManager.shared
        let addressType = settings.selectedConnection.type
        let primitiveFactory = WalletPrimitiveFactory(settings: settings)
        let asset = primitiveFactory.createAssetForAddressType(addressType)

        guard let assetId = WalletAssetId(rawValue: asset.identifier) else {
            return nil
        }

        guard let interactor = createInteractor(for: paraId, assetId: assetId) else {
            return nil
        }

        let wireframe = CrowdloanContributionSetupWireframe()

        let balanceViewModelFactory = BalanceViewModelFactory(
            walletPrimitiveFactory: primitiveFactory,
            selectedAddressType: addressType,
            limit: StakingConstants.maxAmount
        )

        let localizationManager = LocalizationManager.shared
        let amountFormatterFactory = AmountFormatterFactory()

        let contributionViewModelFactory = CrowdloanContributionViewModelFactory(
            amountFormatterFactory: amountFormatterFactory,
            chainDateCalculator: ChainDateCalculator(),
            asset: asset
        )

        let dataValidatingFactory = CrowdloanDataValidatingFactory(
            presentable: wireframe,
            amountFormatterFactory: amountFormatterFactory,
            chain: addressType.chain,
            asset: asset
        )

        let presenter = CrowdloanContributionSetupPresenter(
            interactor: interactor,
            wireframe: wireframe,
            balanceViewModelFactory: balanceViewModelFactory,
            contributionViewModelFactory: contributionViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            chain: addressType.chain,
            localizationManager: localizationManager,
            logger: Logger.shared
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
        assetId: WalletAssetId
    ) -> CrowdloanContributionSetupInteractor? {
        guard let engine = WebSocketService.shared.connection else {
            return nil
        }

        let settings = SettingsManager.shared

        guard let selectedAccount = settings.selectedAccount else {
            return nil
        }

        let chain = settings.selectedConnection.type.chain

        let operationManager = OperationManagerFacade.sharedManager

        let runtimeService = RuntimeRegistryFacade.sharedService

        let extrinsicService = ExtrinsicService(
            address: selectedAccount.address,
            cryptoType: selectedAccount.cryptoType,
            runtimeRegistry: runtimeService,
            engine: engine,
            operationManager: operationManager
        )

        let feeProxy = ExtrinsicFeeProxy()

        let singleValueProviderFactory = SingleValueProviderFactory.shared

        let crowdloanFundsProvider = singleValueProviderFactory.getCrowdloanFunds(
            for: paraId,
            connection: settings.selectedConnection,
            engine: engine,
            runtimeService: runtimeService
        )

        return CrowdloanContributionSetupInteractor(
            paraId: paraId,
            selectedAccountAddress: selectedAccount.address,
            chain: chain,
            assetId: assetId,
            runtimeService: runtimeService,
            feeProxy: feeProxy,
            extrinsicService: extrinsicService,
            crowdloanFundsProvider: crowdloanFundsProvider,
            singleValueProviderFactory: singleValueProviderFactory,
            operationManager: operationManager
        )
    }
}
