import CommonWallet
import SoraFoundation

final class ChooseRecipientPresenter {
    weak var view: ChooseRecipientViewProtocol?
    let wireframe: ChooseRecipientWireframeProtocol
    let interactor: ChooseRecipientInteractorInputProtocol
    let viewModelFactory: ChooseRecipientViewModelFactoryProtocol
    let asset: AssetModel
    let chain: ChainModel
    let selectedAccount: MetaAccountModel
    let qrParser: QRParser
    let transferFinishBlock: WalletTransferFinishBlock?

    private var searchResult: Result<[SearchData]?, Error>?

    init(
        interactor: ChooseRecipientInteractorInputProtocol,
        wireframe: ChooseRecipientWireframeProtocol,
        viewModelFactory: ChooseRecipientViewModelFactoryProtocol,
        asset: AssetModel,
        chain: ChainModel,
        selectedAccount: MetaAccountModel,
        localizationManager: LocalizationManagerProtocol,
        qrParser: QRParser,
        transferFinishBlock: WalletTransferFinishBlock?
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.asset = asset
        self.chain = chain
        self.selectedAccount = selectedAccount
        self.qrParser = qrParser
        self.transferFinishBlock = transferFinishBlock
        self.localizationManager = localizationManager
    }
}

extension ChooseRecipientPresenter: Localizable {
    func applyLocalization() {
        view?.didReceive(locale: selectedLocale)
    }
}

extension ChooseRecipientPresenter: ChooseRecipientPresenterProtocol {
    func didTapPasteButton() {
        if let address = UIPasteboard.general.string {
            view?.didReceive(address: address)
        }
    }

    func didTapBackButton() {
        wireframe.close(view)
    }

    func didTapScanButton() {
        guard let selectedMetaAccount = SelectedWalletSettings.shared.value else {
            return
        }
        wireframe.presentScan(
            from: view,
            chain: chain,
            asset: asset,
            selectedAccount: selectedMetaAccount,
            moduleOutput: self
        )
    }

    func didTapHistoryButton() {
        wireframe.presentHistory(from: view)
    }

    func searchTextDidChanged(_ text: String) {
        interactor.performSearch(query: text)
    }

    func setup() {
        view?.didReceive(locale: selectedLocale)
    }

    func didSelectViewModel(viewModel: SearchPeopleTableCellViewModel) {
        wireframe.presentSendAmount(
            from: view,
            to: viewModel.address,
            asset: asset,
            chain: chain,
            wallet: selectedAccount,
            transferFinishBlock: transferFinishBlock
        )
    }
}

extension ChooseRecipientPresenter: ChooseRecipientInteractorOutputProtocol {
    func didReceive(searchResult: Result<[SearchData]?, Error>) {
        var viewModel: ChooseRecipientViewModel
        switch searchResult {
        case let .success(searchData):
            viewModel = viewModelFactory.buildChooseRecipientViewModel(results: searchData ?? [])
        default:
            viewModel = viewModelFactory.buildChooseRecipientViewModel(results: [])
        }
        view?.didReceive(viewModel: viewModel)
    }
}

extension ChooseRecipientPresenter: WalletScanQRModuleOutput {
    func didFinishWith(payload: TransferPayload) {
        let chainFormat: ChainFormat = chain.isEthereumBased
            ? .ethereum
            : .substrate(chain.addressPrefix)

        guard let accountId = try? Data(hexString: payload.receiveInfo.accountId),
              let address = try? AddressFactory.address(for: accountId, chainFormat: chainFormat) else {
            return
        }

        wireframe.presentSendAmount(
            from: view,
            to: address,
            asset: asset,
            chain: chain,
            wallet: selectedAccount,
            transferFinishBlock: transferFinishBlock
        )
    }

    func didFinishWith(incorrectAddress: String) {
        guard let address = try? qrParser.extractAddress(from: incorrectAddress) else {
            return
        }

        view?.didReceive(address: address)
        searchTextDidChanged(address)
    }
}
