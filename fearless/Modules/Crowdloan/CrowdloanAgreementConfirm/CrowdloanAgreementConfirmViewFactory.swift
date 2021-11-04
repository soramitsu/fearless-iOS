import Foundation
import SoraKeystore
import FearlessUtils
import RobinHood

struct CrowdloanAgreementConfirmViewFactory {
    static func createView(
        paraId: ParaId,
        customFlow: CustomCrowdloanFlow,
        remark: String
    ) -> CrowdloanAgreementConfirmViewProtocol? {
        switch customFlow {
        case let .moonbeam(moonbeamFlowData):
            return createMoonbeamView(
                paraId: paraId,
                moonbeamFlowData: moonbeamFlowData,
                remark: remark
            )
        default:
            return nil
        }
    }
}

extension CrowdloanAgreementConfirmViewFactory {
    private static func createMoonbeamView(
        paraId: ParaId,
        moonbeamFlowData: MoonbeamFlowData,
        remark: String
    ) -> CrowdloanAgreementConfirmViewProtocol? {
        let settings = SettingsManager.shared
        let addressType = settings.selectedConnection.type
        let primitiveFactory = WalletPrimitiveFactory(settings: settings)
        let asset = primitiveFactory.createAssetForAddressType(addressType)

        guard let assetId = WalletAssetId(rawValue: asset.identifier) else {
            return nil
        }

        guard let interactor = createMoonbeamInteractor(
            for: paraId,
            assetId: assetId,
            moonbeamFlowData: moonbeamFlowData,
            remark: remark
        ) else {
            return nil
        }

        let balanceViewModelFactory = BalanceViewModelFactory(
            walletPrimitiveFactory: primitiveFactory,
            selectedAddressType: addressType,
            limit: StakingConstants.maxAmount
        )

        let agreementViewModelFactory = CrowdloanAgreementViewModelFactory(iconGenerator: PolkadotIconGenerator())

        let wireframe = CrowdloanAgreementConfirmWireframe()

        let presenter = CrowdloanAgreementConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            balanceViewModelFactory: balanceViewModelFactory,
            agreementViewModelFactory: agreementViewModelFactory,
            chain: settings.selectedConnection.type.chain,
            logger: Logger.shared,
            paraId: paraId,
            customFlow: .moonbeam(moonbeamFlowData)
        )

        let view = CrowdloanAgreementConfirmViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createMoonbeamInteractor(
        for paraId: ParaId,
        assetId: WalletAssetId,
        moonbeamFlowData: MoonbeamFlowData,
        remark: String
    ) -> CrowdloanAgreementConfirmInteractor? {
        let settings = SettingsManager.shared

        guard let engine = WebSocketService.shared.connection,
              let selectedAccount = settings.selectedAccount,
              let selectedAddress = settings.selectedAccount?.address else {
            return nil
        }

        let chain = settings.selectedConnection.type.chain

        let operationManager = OperationManagerFacade.sharedManager

        let runtimeService = RuntimeRegistryFacade.sharedService

        let signingWrapper = SigningWrapper(
            keystore: Keychain(),
            settings: settings
        )

        let extrinsicService = ExtrinsicService(
            address: selectedAccount.address,
            cryptoType: selectedAccount.cryptoType,
            runtimeRegistry: runtimeService,
            engine: engine,
            operationManager: operationManager
        )

        #if F_DEV
            let apiKey = moonbeamFlowData.devApiKey
            let host = moonbeamFlowData.devApiUrl
        #else
            let apiKey = moonbeamFlowData.prodApiKey
            let host = moonbeamFlowData.prodApiUrl
        #endif

        let headerBuilder = MoonbeamHTTPHeadersBuilder(apiKey: apiKey)
        let requestBuilder = HTTPRequestBuilder(host: host, headerBuilder: headerBuilder)

        let agreementService = MoonbeamService(
            address: selectedAddress,
            chain: settings.selectedConnection.type.chain,
            signingWrapper: signingWrapper,
            operationManager: OperationManagerFacade.sharedManager,
            requestBuilder: requestBuilder,
            dataOperationFactory: DataOperationFactory()
        )

        let singleValueProviderFactory = SingleValueProviderFactory.shared

        let accountRepository: CoreDataRepository<AccountItem, CDAccountItem> =
            UserDataStorageFacade.shared.createRepository()

        let callFactory = SubstrateCallFactory()

        return CrowdloanAgreementConfirmInteractor(
            paraId: paraId,
            selectedAccountAddress: selectedAddress,
            chain: chain,
            assetId: assetId,
            extrinsicService: extrinsicService,
            signingWrapper: signingWrapper,
            accountRepository: AnyDataProviderRepository(accountRepository),
            agreementService: agreementService,
            callFactory: callFactory,
            operationManager: operationManager,
            singleValueProviderFactory: singleValueProviderFactory,
            remark: remark,
            webSocketService: WebSocketService.shared,
            logger: Logger.shared
        )
    }
}
