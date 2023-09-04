typealias RawDataModuleCreationResult = (
    view: RawDataViewInput,
    input: RawDataModuleInput
)

protocol RawDataRouterInput: PresentDismissable {}

protocol RawDataModuleInput: AnyObject {}

protocol RawDataModuleOutput: AnyObject {}
