import Foundation
import SoraFoundation
import SoraKeystore
import RobinHood
import FearlessUtils

struct CrowdloanContributionConfirmViewFactory {
    static func createView(
        with paraId: ParaId,
        inputAmount: Decimal,
        bonusService: CrowdloanBonusServiceProtocol?,
        customFlow: CustomCrowdloanFlow?,
        ethereumAddress: String?
    ) -> CrowdloanContributionConfirmViewProtocol? {
        let settings = SettingsManager.shared
        let addressType = settings.selectedConnection.type
        let primitiveFactory = WalletPrimitiveFactory(settings: settings)
        let asset = primitiveFactory.createAssetForAddressType(addressType)

        guard let assetId = WalletAssetId(rawValue: asset.identifier) else {
            return nil
        }

        var interactor: CrowdloanContributionConfirmInteractor?
        switch customFlow {
        case let .moonbeam(moonbeamFlowData):
            interactor = createMoonbeamInteractor(
                for: paraId,
                assetId: assetId,
                moonbeamFlowData: moonbeamFlowData,
                ethereumAddress: ethereumAddress
            )
        default:
            interactor = createInteractor(
                for: paraId,
                assetId: assetId,
                bonusService: bonusService,
                memo: ethereumAddress
            )
        }

        guard let interactor = interactor else {
            return nil
        }

        let wireframe = CrowdloanContributionConfirmWireframe()

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

        let presenter = CrowdloanContributionConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            balanceViewModelFactory: balanceViewModelFactory,
            contributionViewModelFactory: contributionViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            inputAmount: inputAmount,
            bonusRate: bonusService?.bonusRate,
            chain: addressType.chain,
            localizationManager: localizationManager,
            logger: Logger.shared,
            customFlow: customFlow
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

    private static func createMoonbeamInteractor(
        for paraId: ParaId,
        assetId: WalletAssetId,
        moonbeamFlowData: MoonbeamFlowData,
        ethereumAddress: String?
    ) -> MoonbeamContributionConfirmInteractor? {
        guard let engine = WebSocketService.shared.connection else {
            return nil
        }

        let settings = SettingsManager.shared
        let keystore = Keychain()

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

        let signingWrapper = SigningWrapper(keystore: keystore, settings: settings)

        let accountRepository: CoreDataRepository<AccountItem, CDAccountItem> =
            UserDataStorageFacade.shared.createRepository()

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )

        let crowdloanOperationFactory = CrowdloanOperationFactory(
            requestOperationFactory: storageRequestFactory,
            operationManager: operationManager
        )

        #if F_DEV
            let headerBuilder = MoonbeamHTTPHeadersBuilder(
                apiKey: moonbeamFlowData.devApiKey
            )
        #else
            let headerBuilder = MoonbeamHTTPHeadersBuilder(
                apiKey: moonbeamFlowData.prodApiKey
            )
        #endif

        #if F_DEV
            let requestBuilder = HTTPRequestBuilder(
                host: moonbeamFlowData.devApiUrl,
                headerBuilder: headerBuilder
            )
        #else
            let requestBuilder = HTTPRequestBuilder(
                host: moonbeamFlowData.prodApiUrl,
                headerBuilder: headerBuilder
            )
        #endif
        let agreementService = MoonbeamService(
            address: selectedAccount.address,
            chain: settings.selectedConnection.type.chain,
            signingWrapper: signingWrapper,
            operationManager: OperationManagerFacade.sharedManager,
            requestBuilder: requestBuilder,
            dataOperationFactory: DataOperationFactory()
        )

        return MoonbeamContributionConfirmInteractor(
            paraId: paraId,
            selectedAccountAddress: selectedAccount.address,
            chain: chain,
            assetId: assetId,
            runtimeService: runtimeService,
            feeProxy: feeProxy,
            extrinsicService: extrinsicService,
            signingWrapper: signingWrapper,
            accountRepository: AnyDataProviderRepository(accountRepository),
            crowdloanFundsProvider: crowdloanFundsProvider,
            singleValueProviderFactory: singleValueProviderFactory,
            bonusService: nil,
            operationManager: operationManager,
            moonbeamService: agreementService,
            logger: Logger.shared,
            crowdloanOperationFactory: crowdloanOperationFactory,
            connection: engine,
            ethereumAddress: ethereumAddress,
            settings: SettingsManager.shared
        )
    }

    private static func createInteractor(
        for paraId: ParaId,
        assetId: WalletAssetId,
        bonusService: CrowdloanBonusServiceProtocol?,
        memo: String?
    ) -> CrowdloanContributionConfirmInteractor? {
        guard let engine = WebSocketService.shared.connection else {
            return nil
        }

        let settings = SettingsManager.shared
        let keystore = Keychain()

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

        let signingWrapper = SigningWrapper(keystore: keystore, settings: settings)

        let accountRepository: CoreDataRepository<AccountItem, CDAccountItem> =
            UserDataStorageFacade.shared.createRepository()

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )

        let crowdloanOperationFactory = CrowdloanOperationFactory(
            requestOperationFactory: storageRequestFactory,
            operationManager: operationManager
        )

        return CrowdloanContributionConfirmInteractor(
            paraId: paraId,
            selectedAccountAddress: selectedAccount.address,
            chain: chain,
            assetId: assetId,
            runtimeService: runtimeService,
            feeProxy: feeProxy,
            extrinsicService: extrinsicService,
            signingWrapper: signingWrapper,
            accountRepository: AnyDataProviderRepository(accountRepository),
            crowdloanFundsProvider: crowdloanFundsProvider,
            singleValueProviderFactory: singleValueProviderFactory,
            bonusService: bonusService,
            operationManager: operationManager,
            logger: Logger.shared,
            crowdloanOperationFactory: crowdloanOperationFactory,
            connection: engine,
            settings: SettingsManager.shared,
            memo: memo
        )
    }
}
