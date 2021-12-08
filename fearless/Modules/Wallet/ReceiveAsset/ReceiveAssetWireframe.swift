import UIKit

final class ReceiveAssetWireframe: ReceiveAssetWireframeProtocol {
    func close(_ view: ReceiveAssetViewProtocol) {
        view.controller.navigationController?.dismiss(animated: true)
    }

    func share(
        sources: [Any],
        from view: ControllerBackedProtocol?
    ) {
        guard let controller = view?.controller else {
            return
        }

        let activityController = UIActivityViewController(
            activityItems: sources,
            applicationActivities: nil
        )

        controller.present(activityController, animated: true, completion: nil)
    }
}
