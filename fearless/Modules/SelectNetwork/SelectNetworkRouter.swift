import Foundation

protocol SelectNetworkDelegate: AnyObject {
    func chainSelection(view: SelectNetworkViewInput, didCompleteWith chain: ChainModel?)
}

final class SelectNetworkRouter: SelectNetworkRouterInput {
    private weak var delegate: SelectNetworkDelegate?

    init(delegate: SelectNetworkDelegate?) {
        self.delegate = delegate
    }

    func complete(on view: SelectNetworkViewInput, selecting chain: ChainModel?) {
        view.controller.dismiss(animated: true)
        delegate?.chainSelection(view: view, didCompleteWith: chain)
    }
}
