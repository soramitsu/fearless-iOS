import Foundation

protocol ProfileViewProtocol: ControllerBackedProtocol {
    func didLoad(userViewModel: ProfileUserViewModelProtocol)
    func didLoad(optionViewModels: [ProfileOptionViewModelProtocol])
}

protocol ProfilePresenterProtocol: class {
    func setup()
    func activateUserDetails()
    func activateOption(at index: UInt)
}

protocol ProfileInteractorInputProtocol: class {
    func setup()
}

protocol ProfileInteractorOutputProtocol: class {
    func didReceive(userData: UserData)
    func didReceiveUserDataProvider(error: Error)
}

protocol ProfileWireframeProtocol: ErrorPresentable, AlertPresentable, WebPresentable {
    func showPassphraseView(from view: ProfileViewProtocol?)
    func showNodeSelection(from view: ProfileViewProtocol?)
    func showLanguageSelection(from view: ProfileViewProtocol?)
    func showAbout(from view: ProfileViewProtocol?)
}

protocol ProfileViewFactoryProtocol: class {
	static func createView() -> ProfileViewProtocol?
}
