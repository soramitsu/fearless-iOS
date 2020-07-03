import Foundation

protocol AccessBackupViewProtocol: ControllerBackedProtocol {
    func didReceiveBackup(mnemonic: String)
}

protocol AccessBackupPresenterProtocol: class {
    func setup()
    func activateSharing()
    func activateNext()
}

protocol AccessBackupInteractorInputProtocol: class {
    func load()
}

protocol AccessBackupInteractorOutputProtocol: class {
    func didLoad(mnemonic: String)
    func didReceive(error: Error)
}

enum AccessBackupInteractorError: Error {
    case loading
}

protocol AccessBackupWireframeProtocol: SharingPresentable, AlertPresentable, ErrorPresentable {
    func showNext(from view: AccessBackupViewProtocol?)
}

protocol AccessBackupViewFactoryProtocol: class {
    static func createView() -> AccessBackupViewProtocol?
}
