import Foundation

struct SignerConnectViewFactory {
    static func createBeaconView(for info: BeaconConnectionInfo) -> SignerConnectViewProtocol? {
        let interactor = SignerConnectInteractor(info: info, logger: Logger.shared)
        let wireframe = SignerConnectWireframe()

        let presenter = SignerConnectPresenter(interactor: interactor, wireframe: wireframe)

        let view = SignerConnectViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
