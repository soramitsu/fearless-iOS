import Foundation

typealias CreateContactModuleCreationResult = (view: CreateContactViewInput, input: CreateContactModuleInput)

protocol CreateContactViewInput: ControllerBackedProtocol {
    func didReceive(locale: Locale)
    func didReceive(viewModel: CreateContactViewModel)
    func updateState(isValid: Bool)
}

protocol CreateContactViewOutput: AnyObject {
    func didLoad(view: CreateContactViewInput)
    func didTapBackButton()
    func didTapCreateButton()
    func didTapSelectNetwork()
    func addressTextDidChanged(_ address: String)
    func nameTextDidChanged(_ name: String)
}

protocol CreateContactInteractorInput: AnyObject {
    func setup(with output: CreateContactInteractorOutput)
    func validate(address: String, for chain: ChainModel) -> Bool
}

protocol CreateContactInteractorOutput: AnyObject {}

protocol CreateContactRouterInput: PushDismissable, ErrorPresentable, SheetAlertPresentable {
    func showSelectNetwork(
        from view: CreateContactViewInput?,
        wallet: MetaAccountModel,
        selectedChainId: ChainModel.Id?,
        delegate: SelectNetworkDelegate?
    )
}

protocol CreateContactModuleInput: AnyObject {}

protocol CreateContactModuleOutput: AnyObject {
    func didCreate(contact: Contact)
}
