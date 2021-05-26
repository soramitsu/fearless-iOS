import Foundation
import SoraKeystore
import SoraFoundation

struct CrowdloanContributionSetupViewFactory {
    static func createView(for paraId: ParaId) -> CrowdloanContributionSetupViewProtocol? {
        guard let interactor = createInteractor(for: paraId) else {
            return nil
        }

        let wireframe = CrowdloanContributionSetupWireframe()

        let settings = SettingsManager.shared
        let addressType = settings.selectedConnection.type
        let primitiveFactory = WalletPrimitiveFactory(settings: settings)
        let asset = primitiveFactory.createAssetForAddressType(addressType)

        let balanceViewModelFactory = BalanceViewModelFactory(
            walletPrimitiveFactory: primitiveFactory,
            selectedAddressType: addressType,
            limit: StakingConstants.maxAmount
        )

        let localizationManager = LocalizationManager.shared

        let contributionViewModelFactory = CrowdloanContributionViewModelFactory(
            amountFormatterFactory: AmountFormatterFactory(),
            chainDateCalculator: ChainDateCalculator(),
            asset: asset
        )

        let presenter = CrowdloanContributionSetupPresenter(
            interactor: interactor,
            wireframe: wireframe,
            balanceViewModelFactory: balanceViewModelFactory,
            contributionViewModelFactory: contributionViewModelFactory,
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

        return view
    }

    private static func createInteractor(for paraId: ParaId) -> CrowdloanContributionSetupInteractor? {
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
            runtimeService: runtimeService,
            feeProxy: feeProxy,
            extrinsicService: extrinsicService,
            crowdloanFundsProvider: crowdloanFundsProvider,
            singleValueProviderFactory: singleValueProviderFactory,
            operationManager: operationManager
        )
    }
}
