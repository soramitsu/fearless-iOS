import SSFModels

typealias MultiSelectNetworksModuleCreationResult = (
    view: MultiSelectNetworksViewInput,
    input: MultiSelectNetworksModuleInput
)

protocol MultiSelectNetworksRouterInput: PresentDismissable {}

protocol MultiSelectNetworksModuleInput: AnyObject {}

protocol MultiSelectNetworksModuleOutput: AnyObject {
    func selectedChain(ids: [ChainModel.Id]?)
}
