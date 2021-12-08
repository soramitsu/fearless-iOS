import UIKit
import SoraFoundation

protocol ReceiveAssetPresenterProtocol: AnyObject {
    func setup()
    func share(qrImage: UIImage)
    func didTapCloseButton()
}

protocol ReceiveAssetViewProtocol: ControllerBackedProtocol, Localizable {
    func bind(viewModel: ReceiveAssetViewModel)
    func didReceive(image: UIImage)
}

protocol ReceiveAssetWireframeProtocol {
    func close(_ view: ReceiveAssetViewProtocol)
    func share(sources: [Any], from view: ControllerBackedProtocol?)
}
