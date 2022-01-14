import Foundation
import RobinHood
import SoraFoundation

struct WalletScanQRViewFactory {
    static func createView(
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel,
        moduleOutput: WalletScanQRModuleOutput?
    ) -> WalletScanQRViewProtocol? {
        guard let account = selectedAccount.fetch(for: chain.accountRequest()), let address = account.toAddress() else {
            return nil
        }

        let interactor = WalletScanQRInteractor()
        let wireframe = WalletScanQRWireframe()

        let localSearchEngine = InvoiceScanLocalSearchEngine(addressPrefix: chain.addressPrefix)

        let qrCoderFactory = WalletQRCoderFactory(
            addressPrefix: chain.addressPrefix,
            publicKey: account.publicKey,
            username: account.name,
            asset: asset
        )

        let accountStorage: CoreDataRepository<MetaAccountModel, CDMetaAccount> =
            UserDataStorageFacade.shared
                .createRepository(
                    filter: nil,
                    sortDescriptors: [NSSortDescriptor.accountsByOrder],
                    mapper: AnyCoreDataMapper(MetaAccountMapper())
                )

        let contactsOperationFactory = WalletContactOperationFactory(
            storageFacade: SubstrateDataStorageFacade.shared,
            targetAddress: ""
        )

        let searchService = SearchService(
            operationManager: OperationManagerFacade.sharedManager,
            contactsOperationFactory: contactsOperationFactory,
            accountsRepository: AnyDataProviderRepository(accountStorage)
        )

        let presenter = WalletScanQRPresenter(
            interactor: interactor,
            wireframe: wireframe,
            currentAccountId: address,
            searchService: searchService,
            localSearchEngine: localSearchEngine,
            qrScanServiceFactory: QRCaptureServiceFactory(),
            qrCoderFactory: qrCoderFactory,
            localizationManager: LocalizationManager.shared,
            chain: chain,
            moduleOutput: moduleOutput,
            qrExtractionService: QRExtractionService(processingQueue: .global())
        )

        let view = WalletScanQRViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
