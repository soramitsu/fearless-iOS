import CommonWallet
import SoraFoundation
import IrohaCrypto
import CoreGraphics
import FearlessUtils

final class ReceiveAssetPresenter {
    enum Constants {
        static let qrSize = CGSize(width: 240, height: 240)
    }

    weak var view: ReceiveAssetViewProtocol?

    private let wireframe: ReceiveAssetWireframeProtocol
    private let qrService: WalletQRServiceProtocol
    private let addressFactory = SS58AddressFactory()
    private let sharingFactory: AccountShareFactoryProtocol

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
        asset: AssetModel,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.wireframe = wireframe
        self.qrService = qrService
        self.sharingFactory = sharingFactory
        self.account = account
        self.chain = chain
        self.asset = asset
        self.localizationManager = localizationManager
    }

    private var address: String? {
        account.fetch(for: chain.accountRequest())?.toAddress()
    }
}

extension ReceiveAssetPresenter: ReceiveAssetPresenterProtocol {
    func setup() {
        view?.didReceive(locale: selectedLocale)
        provideViewModel()
        generateQR()
    }

    func share(qrImage: UIImage) {
        guard let address = address else {
            assertionFailure()
            return
        }

        let sources = sharingFactory.createSources(
            accountAddress: address,
            qrImage: qrImage,
            assetSymbol: asset.id,
            chainName: chain.name,
            locale: selectedLocale
        )

        wireframe.share(sources: sources, from: view, with: nil)
    }

    func close() {
        if let view = self.view {
            wireframe.close(view)
        }
    }

    func presentAccountOptions() {
        guard let address = account.fetch(for: chain.accountRequest())?.toAddress(), let view = view else {
            return
        }

        wireframe.presentAccountOptions(
            from: view,
            address: address,
            chain: chain,
            locale: selectedLocale
        )
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

        guard let accountId = account.fetch(for: chain.accountRequest())?.accountId else {
            processOperation(result: .failure(ChainAccountFetchingError.accountNotExists))
            return
        }

        let receiveInfo = ReceiveInfo(
            accountId: accountId.toHex(),
            assetId: asset.id,
            amount: nil,
            details: nil
        )
        do {
            qrOperation = try qrService.generate(
                from: receiveInfo,
                qrSize: Constants.qrSize,
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
            wireframe.present(error: error, from: view, locale: selectedLocale)
        }
    }

    private func provideViewModel() {
        guard let address = address else {
            assertionFailure()
            return
        }

        view?.didReceive(viewModel: ReceiveAssetViewModel(
            asset: asset.name,
            accountName: account.name,
            address: address
        ))
    }
}
