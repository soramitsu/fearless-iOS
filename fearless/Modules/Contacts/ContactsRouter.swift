import Foundation

final class ContactsRouter: ContactsRouterInput {
    func createContact(
        address: String?,
        chain: ChainModel,
        wallet: MetaAccountModel,
        output: CreateContactModuleOutput,
        view: ControllerBackedProtocol?
    ) {
        let module = CreateContactAssembly.configureModule(
            moduleOutput: output,
            wallet: wallet,
            chain: chain,
            address: address
        )
        guard let controller = module?.view.controller else {
            return
        }
        view?.controller.navigationController?.pushViewController(controller, animated: true)
    }
}
