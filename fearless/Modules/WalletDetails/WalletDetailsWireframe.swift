final class WalletDetailsWireframe: WalletDetailsWireframeProtocol {
    func close(_ view: WalletDetailsViewProtocol) {
        view.controller.navigationController?.dismiss(animated: true)
    }
}
