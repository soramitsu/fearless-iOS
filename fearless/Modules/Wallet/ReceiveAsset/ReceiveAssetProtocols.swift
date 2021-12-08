import UIKit
import SoraFoundation

protocol ReceiveAssetPresenterProtocol: AnyObject {
    func setup()
    func didTapCloseButton()
    func didTapShareButton()
}

protocol ReceiveAssetViewProtocol: ControllerBackedProtocol, Localizable {
    func bind(viewModel: ReceiveAssetViewModel)
    func didReceive(image: UIImage)
}

protocol ReceiveAssetWireframeProtocol {
    func close(_ view: ReceiveAssetViewProtocol)
}
