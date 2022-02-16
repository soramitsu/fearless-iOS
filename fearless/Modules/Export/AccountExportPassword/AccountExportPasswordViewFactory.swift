import Foundation
import SoraFoundation
import SoraKeystore
import RobinHood

final class AccountExportPasswordViewFactory: AccountExportPasswordViewFactoryProtocol {
    static func createView(with address: String, chain: ChainModel) -> AccountExportPasswordViewProtocol? {
        let localizationManager = LocalizationManager.shared

        let view = AccountExportPasswordViewController(nib: R.nib.accountExportPasswordViewController)
        let presenter = AccountExportPasswordPresenter(
            address: address,
            chain: chain,
            localizationManager: localizationManager
        )

        let exportJsonWrapper = KeystoreExportWrapper(keystore: Keychain())

        let repository = AccountRepositoryFactory.createRepository()

        let chainRegistry = ChainRegistryFacade.sharedRegistry
        guard
            let selectedAccount = SelectedWalletSettings.shared.value,
            let connection = chainRegistry.getConnection(for: chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId),
            let accountResponse = selectedAccount.fetch(for: chain.accountRequest()) else {
            return nil
        }
        let extrinsicOperationFactory = ExtrinsicOperationFactory(
            accountId: accountResponse.accountId,
            chainFormat: chain.chainFormat,
            cryptoType: accountResponse.cryptoType,
            runtimeRegistry: runtimeService,
            engine: connection
        )

        let interactor = AccountExportPasswordInteractor(
            exportJsonWrapper: exportJsonWrapper,
            repository: repository,
            operationManager: OperationManagerFacade.sharedManager,
            extrinsicOperationFactory: extrinsicOperationFactory
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
