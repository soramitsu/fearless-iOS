typealias NetworkManagmentModuleCreationResult = (
    view: NetworkManagmentViewInput,
    input: NetworkManagmentModuleInput
)

protocol NetworkManagmentRouterInput: AnyDismissable {}

protocol NetworkManagmentModuleInput: AnyObject {}

protocol NetworkManagmentModuleOutput: AnyObject {
    func did(select: NetworkManagmentSelect, contextTag: Int?)
}
