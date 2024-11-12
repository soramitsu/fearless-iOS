import SSFModels

typealias ConfirmTransferModuleCreationResult = (
    view: ConfirmTransferViewInput,
    input: ConfirmTransferModuleInput
)

@MainActor
protocol ConfirmTransferRouterInput:
    ErrorPresentable,
    BaseErrorPresentable,
    ModalAlertPresenting,
    SheetAlertPresentable {
    func close(view: ControllerBackedProtocol?)
    func finish(view: ControllerBackedProtocol?)
    func complete(
        on view: ControllerBackedProtocol?,
        title: String?,
        chainAsset: ChainAsset
    )
}

protocol ConfirmTransferModuleInput: AnyObject {}

protocol ConfirmTransferModuleOutput: AnyObject {}
