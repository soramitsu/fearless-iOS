typealias BridgeListModuleCreationResult = (
    view: BridgeListViewInput,
    input: BridgeListModuleInput
)

protocol BridgeListRouterInput: AnyObject, PushDismissable {}

protocol BridgeListModuleInput: AnyObject {}

protocol BridgeListModuleOutput: AnyObject {
    func didUpdateSelectedSort(_ sort: UInt8)
}
