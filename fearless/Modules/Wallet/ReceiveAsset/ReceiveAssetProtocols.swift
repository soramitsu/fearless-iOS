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

protocol ReceiveAssetWireframeProtocol: AlertPresentable, ErrorPresentable, SharingPresentable {
    func close(_ view: ReceiveAssetViewProtocol)
}
