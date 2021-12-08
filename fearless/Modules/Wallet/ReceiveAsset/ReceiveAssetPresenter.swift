import CommonWallet
import SoraFoundation

final class ReceiveAssetPresenter {
    weak var view: ReceiveAssetViewProtocol?

    private let wireframe: ReceiveAssetWireframe
//    private let qrService: WalletQRServiceProtocol
    private let sharingFactory: AccountShareFactoryProtocol

    private var qrOperation: Operation?

    deinit {
        cancelQRGeneration()
    }

    init(
        wireframe: ReceiveAssetWireframe,
//        qrService: WalletQRServiceProtocol,
        sharingFactory: AccountShareFactoryProtocol
    ) {
        self.wireframe = wireframe
//        self.qrService = qrService
        self.sharingFactory = sharingFactory
    }

    private func cancelQRGeneration() {
        qrOperation?.cancel()
        qrOperation = nil
    }

    private func provideViewModel() {
        
    }
}

extension ReceiveAssetPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideViewModel()
        }
    }
}
