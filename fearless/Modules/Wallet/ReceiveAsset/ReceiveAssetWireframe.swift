final class ReceiveAssetWireframe: ReceiveAssetWireframeProtocol {
    func close(_ view: ReceiveAssetViewProtocol) {
        view.controller.navigationController?.dismiss(animated: true)
    }
}
