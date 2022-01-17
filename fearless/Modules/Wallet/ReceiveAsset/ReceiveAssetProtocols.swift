import UIKit
import SoraFoundation
import CommonWallet

protocol ReceiveAssetPresenterProtocol: AnyObject {
    func setup()
    func share(qrImage: UIImage)
    func didTapCloseButton()
    func presentAccountOptions()
}

protocol ReceiveAssetViewProtocol: ControllerBackedProtocol, Localizable {
    func bind(viewModel: ReceiveAssetViewModel)
    func didReceive(image: UIImage)
}

protocol ReceiveAssetWireframeProtocol: AlertPresentable, ErrorPresentable, SharingPresentable, AddressOptionsPresentable {
    func close(_ view: ReceiveAssetViewProtocol)
}
