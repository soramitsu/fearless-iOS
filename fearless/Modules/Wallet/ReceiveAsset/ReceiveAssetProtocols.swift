import UIKit
import SoraFoundation
import CommonWallet

protocol ReceiveAssetPresenterProtocol: AnyObject {
    func setup()
    func share(qrImage: UIImage)
    func didTapCloseButton()
}

protocol ReceiveAssetViewProtocol: ControllerBackedProtocol, Localizable {
    func bind(viewModel: ReceiveAssetViewModel)
    func didReceive(image: UIImage)
}

protocol ReceiveAssetWireframeProtocol: ErrorPresentable {
    func close(_ view: ReceiveAssetViewProtocol)
    func share(sources: [Any], from view: ControllerBackedProtocol?)
}
