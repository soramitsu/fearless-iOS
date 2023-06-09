import Foundation
import SSFModels

final class ContactsRouter: ContactsRouterInput {
    func createContact(
        address: String?,
        chain: ChainModel,
        output: CreateContactModuleOutput,
        view: ControllerBackedProtocol?
    ) {
        let module = CreateContactAssembly.configureModule(
            moduleOutput: output,
            chain: chain,
            address: address
        )
        guard let controller = module?.view.controller else {
            return
        }
        view?.controller.navigationController?.pushViewController(controller, animated: true)
    }
}
