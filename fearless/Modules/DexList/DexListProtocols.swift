typealias DexListModuleCreationResult = (
    view: DexListViewInput,
    input: DexListModuleInput
)

protocol DexListRouterInput: AnyObject, PushDismissable {}

protocol DexListModuleInput: AnyObject {}

protocol DexListModuleOutput: AnyObject {
    func didUpdateSelectedDexIds(_ selectedDexIds: [String]?)
}
