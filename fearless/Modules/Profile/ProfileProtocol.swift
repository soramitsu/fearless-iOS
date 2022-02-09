import Foundation

protocol ProfileViewProtocol: ControllerBackedProtocol {
    func didLoad(userViewModel: ProfileUserViewModelProtocol)
    func didLoad(
        optionViewModels: [ProfileOptionViewModelProtocol],
        logoutViewModel: ProfileOptionViewModelProtocol
    )
}

protocol ProfilePresenterProtocol: AnyObject {
    func setup()
    func activateAccountDetails()
    func activateOption(at index: UInt)
    func logout()
}

protocol ProfileInteractorInputProtocol: AnyObject {
    func setup()
    func updateWallet(_ wallet: MetaAccountModel)
    func logout(completion: @escaping () -> Void)
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
    func logout(from view: ProfileViewProtocol?)
    func showCheckPincode(
        from view: ProfileViewProtocol?,
        output: CheckPincodeModuleOutput
    )
}

protocol ProfileViewFactoryProtocol: AnyObject {
    static func createView() -> ProfileViewProtocol?
}
