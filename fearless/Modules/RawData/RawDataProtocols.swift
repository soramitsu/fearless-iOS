typealias RawDataModuleCreationResult = (
    view: RawDataViewInput,
    input: RawDataModuleInput
)

protocol RawDataRouterInput: PresentDismissable, SheetAlertPresentable, ErrorPresentable {}

protocol RawDataModuleInput: AnyObject {}

protocol RawDataModuleOutput: AnyObject {}
