import CommonWallet
import SoraFoundation

final class ChooseRecipientPresenter {
    weak var view: ChooseRecipientViewProtocol?
    let router: ChooseRecipientRouterProtocol
    let interactor: ChooseRecipientInteractorInputProtocol
    let viewModelFactory: ChooseRecipientViewModelFactoryProtocol
    let asset: AssetModel
    let chain: ChainModel
    let wallet: MetaAccountModel
    let qrParser: QRParser

    private var searchResult: Result<[SearchData]?, Error>?

    init(
        interactor: ChooseRecipientInteractorInputProtocol,
        router: ChooseRecipientRouterProtocol,
        viewModelFactory: ChooseRecipientViewModelFactoryProtocol,
        asset: AssetModel,
        chain: ChainModel,
        wallet: MetaAccountModel,
        localizationManager: LocalizationManagerProtocol,
        qrParser: QRParser
    ) {
        self.interactor = interactor
        self.router = router
        self.viewModelFactory = viewModelFactory
        self.asset = asset
        self.chain = chain
        self.wallet = wallet
        self.qrParser = qrParser
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
        router.close(view)
    }

    func didTapScanButton() {
        router.presentScan(
            from: view,
            chain: chain,
            asset: asset,
            selectedAccount: wallet,
            moduleOutput: self
        )
    }

    func didTapHistoryButton() {
        router.presentHistory(from: view)
    }

    func didTapNextButton(with address: String) {
        router.presentSendAmount(
            from: view,
            to: address,
            asset: asset,
            chain: chain,
            wallet: wallet
        )
    }

    func searchTextDidChanged(_ text: String) {
        interactor.performSearch(query: text)
        let viewModel = viewModelFactory.buildChooseRecipientViewModel(
            address: text,
            isValid: interactor.validate(address: text)
        )
        view?.didReceive(viewModel: viewModel)
    }

    func setup() {
        view?.didReceive(locale: selectedLocale)
    }

    func didSelectViewModel(cellViewModel: SearchPeopleTableCellViewModel) {
        let viewModel = viewModelFactory.buildChooseRecipientViewModel(
            address: cellViewModel.address,
            isValid: true
        )
        view?.didReceive(viewModel: viewModel)
    }
}

extension ChooseRecipientPresenter: ChooseRecipientInteractorOutputProtocol {
    func didReceive(searchResult: Result<[SearchData]?, Error>) {
        var viewModel: ChooseRecipientTableViewModel
        switch searchResult {
        case let .success(searchData):
            viewModel = viewModelFactory.buildChooseRecipientTableViewModel(results: searchData ?? [])
        default:
            viewModel = viewModelFactory.buildChooseRecipientTableViewModel(results: [])
        }
        view?.didReceive(tableViewModel: viewModel)
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

        router.presentSendAmount(
            from: view,
            to: address,
            asset: asset,
            chain: chain,
            wallet: wallet
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
