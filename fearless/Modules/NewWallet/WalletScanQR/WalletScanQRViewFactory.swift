import Foundation
import RobinHood
import SoraFoundation
import SSFModels

struct WalletScanQRViewFactory {
    static func createView(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        moduleOutput: WalletScanQRModuleOutput?
    ) -> WalletScanQRViewProtocol? {
        guard let account = wallet.fetch(for: chainAsset.chain.accountRequest()),
              let address = account.toAddress() else {
            return nil
        }

        let interactor = WalletScanQRInteractor()
        let wireframe = WalletScanQRWireframe()

        let chainFormat: ChainFormat =
            chainAsset.chain.isEthereumBased ? .ethereum : .substrate(chainAsset.chain.addressPrefix)
        let localSearchEngine = InvoiceScanLocalSearchEngine(chainFormat: chainFormat)

        let qrCoderFactory = WalletQRCoderFactory(
            addressPrefix: chainAsset.chain.addressPrefix,
            publicKey: account.publicKey,
            username: account.name,
            asset: chainAsset.asset
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
            chain: chainAsset.chain,
            moduleOutput: moduleOutput,
            qrExtractionService: QRExtractionService(processingQueue: .global())
        )

        let view = WalletScanQRViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
