import Foundation

protocol ProfileViewProtocol: ControllerBackedProtocol {
    func didLoad(userViewModel: ProfileUserViewModelProtocol)
    func didLoad(optionViewModels: [ProfileOptionViewModelProtocol])
}

protocol ProfilePresenterProtocol: AnyObject {
    func setup()
    func activateAccountDetails()
    func activateOption(at index: UInt)
}

protocol ProfileInteractorInputProtocol: AnyObject {
    func setup()
    func updateWallet(_ wallet: MetaAccountModel)
}

protocol ProfileInteractorOutputProtocol: AnyObject {
    func didReceive(wallet: MetaAccountModel)
    func didReceiveUserDataProvider(error: Error)
}

protocol ProfileWireframeProtocol: ErrorPresentable,
    AlertPresentable,
    WebPresentable,
    ModalAlertPresenting,
    AddressOptionsPresentable {
    func showAccountDetails(
        from view: ProfileViewProtocol?,
        metaAccount: MetaAccountModel
    )
    func showAccountSelection(from view: ProfileViewProtocol?)
    func showConnectionSelection(from view: ProfileViewProtocol?)
    func showLanguageSelection(from view: ProfileViewProtocol?)
    func showPincodeChange(from view: ProfileViewProtocol?)
    func showAbout(from view: ProfileViewProtocol?)
}

protocol ProfileViewFactoryProtocol: AnyObject {
    static func createView() -> ProfileViewProtocol?
}
