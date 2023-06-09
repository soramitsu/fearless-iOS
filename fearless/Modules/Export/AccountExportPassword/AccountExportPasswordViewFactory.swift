import Foundation
import SoraFoundation
import SoraKeystore
import RobinHood
import SSFModels

final class AccountExportPasswordViewFactory: AccountExportPasswordViewFactoryProtocol {
    static func createView(flow: ExportFlow) -> AccountExportPasswordViewProtocol? {
        let localizationManager = LocalizationManager.shared

        let view = AccountExportPasswordViewController(nib: R.nib.accountExportPasswordViewController)
        let presenter = AccountExportPasswordPresenter(
            flow: flow,
            localizationManager: localizationManager
        )

        let exportJsonWrapper = KeystoreExportWrapper(keystore: Keychain())

        let accountRepository = AccountRepositoryFactory.createRepository()

        let chainRegistry = ChainRegistryFacade.sharedRegistry

        var extrinsicOperationFactory: ExtrinsicOperationFactoryProtocol?

        if case let .single(chain, _, wallet) = flow,
           let connection = chainRegistry.getConnection(for: chain.chainId),
           let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId),
           let accountResponse = wallet.fetch(for: chain.accountRequest()) {
            extrinsicOperationFactory = ExtrinsicOperationFactory(
                accountId: accountResponse.accountId,
                chainFormat: chain.chainFormat,
                cryptoType: accountResponse.cryptoType,
                runtimeRegistry: runtimeService,
                engine: connection
            )
        }

        let repository = ChainRepositoryFactory().createRepository(
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )

        let interactor = AccountExportPasswordInteractor(
            exportJsonWrapper: exportJsonWrapper,
            accountRepository: accountRepository,
            operationManager: OperationManagerFacade.sharedManager,
            extrinsicOperationFactory: extrinsicOperationFactory,
            chainRepository: AnyDataProviderRepository(repository)
        )
        let wireframe = AccountExportPasswordWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        view.localizationManager = localizationManager

        return view
    }
}
