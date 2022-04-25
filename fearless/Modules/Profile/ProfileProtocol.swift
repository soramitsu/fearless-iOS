import Foundation

protocol ProfileViewProtocol: ControllerBackedProtocol {
    func didReceive(state: ProfileViewState)
}

protocol ProfilePresenterProtocol: AnyObject {
    func didLoad(view: ProfileViewProtocol)
    func activateAccountDetails()
    func activateOption(at index: UInt)
    func logout()
    func switcherValueChanged(isOn: Bool)
}

protocol ProfileInteractorInputProtocol: AnyObject {
    func setup(with output: ProfileInteractorOutputProtocol)
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
    func close(view: ControllerBackedProtocol?)
}

protocol ProfileViewFactoryProtocol: AnyObject {
    static func createView() -> ProfileViewProtocol?
}
