import CommonWallet
import SoraFoundation
import IrohaCrypto

final class ReceiveAssetPresenter {
    weak var view: ReceiveAssetViewProtocol?

    private let wireframe: ReceiveAssetWireframeProtocol
    private let qrService: WalletQRServiceProtocol
    private let sharingFactory: AccountShareFactoryProtocol
    private let addressFactory: SS58AddressFactoryProtocol

    private let account: MetaAccountModel
    private let chain: ChainModel
    private let asset: AssetModel

    private var qrOperation: Operation?

    deinit {
        cancelQRGeneration()
    }

    init(
        wireframe: ReceiveAssetWireframe,
        qrService: WalletQRServiceProtocol,
        sharingFactory: AccountShareFactoryProtocol,
        account: MetaAccountModel,
        chain: ChainModel,
        asset: AssetModel
    ) {
        self.wireframe = wireframe
        self.qrService = qrService
        self.sharingFactory = sharingFactory
        self.account = account
        self.chain = chain
        self.asset = asset
    }
}

extension ReceiveAssetPresenter: ReceiveAssetPresenterProtocol {
    func setup() {
        provideViewModel()
        generateQR()
    }

    func share(qrImage: UIImage) {
        let receiveInfo = ReceiveInfo(accountId: account.identifier, assetId: nil, amount: nil, details: nil)
        let sources = sharingFactory.createSources(
            for: receiveInfo,
            qrImage: qrImage
        )

        wireframe.share(
            sources: sources,
            from: view
        )
    }

    func didTapCloseButton() {
        if let view = self.view {
            wireframe.close(view)
        }
    }
}

extension ReceiveAssetPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideViewModel()
        }
    }
}

private extension ReceiveAssetPresenter {
    private func generateQR() {
        cancelQRGeneration()

        do {
            qrOperation = try qrService.generate(
                from: receiveInfo,
                qrSize: size,
                runIn: .main
            ) { [weak self] operationResult in
                if let result = operationResult {
                    self?.qrOperation = nil
                    self?.processOperation(result: result)
                }
            }
        } catch {
            processOperation(result: .failure(error))
        }
    }

    private func cancelQRGeneration() {
        qrOperation?.cancel()
        qrOperation = nil
    }

    private func processOperation(result: Result<UIImage, Error>) {
        switch result {
        case let .success(image):
            view?.didReceive(image: image)
        case let .failure(error):
            view?.showError(error)
        }
    }

    private func provideViewModel() {
        view?.bind(viewModel: ReceiveAssetViewModel(
            selectedAsset: asset.symbol,
            accountName: account.name,
            address: address(for: chain)
        ))
    }

    private func address(for chain: ChainModel) -> String {
        addressFactory.addressFromAccountId(data: account.identifier, addressPrefix: chain.addressPrefix)
    }
}
