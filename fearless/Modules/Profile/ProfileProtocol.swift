import Foundation

protocol ProfileViewProtocol: ControllerBackedProtocol {
    func didLoad(userViewModel: ProfileUserViewModelProtocol)
    func didLoad(optionViewModels: [ProfileOptionViewModelProtocol])
}

protocol ProfilePresenterProtocol: class {
    func setup()
    func activateAccountDetails()
    func activateOption(at index: UInt)
}

protocol ProfileInteractorInputProtocol: class {
    func setup()
}

protocol ProfileInteractorOutputProtocol: class {
    func didReceive(userSettings: UserSettings)
    func didReceiveUserDataProvider(error: Error)
}

protocol ProfileWireframeProtocol: ErrorPresentable, AlertPresentable, WebPresentable, ModalAlertPresenting {
    func showAccountDetails(from view: ProfileViewProtocol?)
    func showAccountSelection(from view: ProfileViewProtocol?)
    func showConnectionSelection(from view: ProfileViewProtocol?)
    func showLanguageSelection(from view: ProfileViewProtocol?)
    func showPincodeChange(from view: ProfileViewProtocol?)
    func showAbout(from view: ProfileViewProtocol?)
}

protocol ProfileViewFactoryProtocol: class {
	static func createView() -> ProfileViewProtocol?
}
