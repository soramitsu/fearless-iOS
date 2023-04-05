import Foundation

protocol SelectNetworkDelegate: AnyObject {
    func chainSelection(
        view: SelectNetworkViewInput,
        didCompleteWith chain: ChainModel?,
        contextTag: Int?
    )
}

final class SelectNetworkRouter: SelectNetworkRouterInput {
    private weak var delegate: SelectNetworkDelegate?

    init(delegate: SelectNetworkDelegate?) {
        self.delegate = delegate
    }

    func complete(
        on view: SelectNetworkViewInput,
        selecting chain: ChainModel?,
        contextTag: Int?
    ) {
        view.controller.dismiss(animated: true)
        delegate?.chainSelection(
            view: view,
            didCompleteWith: chain,
            contextTag: contextTag
        )
    }
}
