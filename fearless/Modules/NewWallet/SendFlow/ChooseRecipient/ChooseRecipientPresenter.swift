import CommonWallet
import SoraFoundation
import Foundation

final class ChooseRecipientPresenter {
    weak var view: ChooseRecipientViewProtocol?
    private let router: ChooseRecipientRouterProtocol
    private let interactor: ChooseRecipientInteractorInputProtocol
    private let viewModelFactory: ChooseRecipientViewModelFactoryProtocol
    private let chainAsset: ChainAsset
    private let wallet: MetaAccountModel
    private let qrParser: QRParser

    private var scamInfo: ScamInfo?

    private var searchResult: Result<[SearchData]?, Error>?

    init(
        interactor: ChooseRecipientInteractorInputProtocol,
        router: ChooseRecipientRouterProtocol,
        viewModelFactory: ChooseRecipientViewModelFactoryProtocol,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        localizationManager: LocalizationManagerProtocol,
        qrParser: QRParser,
        address: String?
    ) {
        self.interactor = interactor
        self.router = router
        self.viewModelFactory = viewModelFactory
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.qrParser = qrParser
        self.localizationManager = localizationManager

        if let address = address {
            view?.didReceive(address: address)
        }
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
            interactor.performSearch(query: address)
            let viewModel = viewModelFactory.buildChooseRecipientViewModel(
                address: address,
                isValid: interactor.validate(address: address)
            )
            view?.didReceive(viewModel: viewModel)
        }
    }

    func didTapBackButton() {
        router.close(view)
    }

    func didTapScanButton() {
        router.presentScan(
            from: view,
            chainAsset: chainAsset,
            wallet: wallet,
            moduleOutput: self
        )
    }

    func didTapHistoryButton() {
        router.presentHistory(from: view, wallet: wallet, chainAsset: chainAsset, moduleOutput: self)
    }

    func didTapNextButton(with address: String) {
        router.presentSendAmount(
            from: view,
            to: address,
            chainAsset: chainAsset,
            wallet: wallet,
            scamInfo: scamInfo
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
        interactor.setup(with: self)
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
    func didReceive(scamInfo: ScamInfo?) {
        view?.didReceive(scamInfo: scamInfo, assetName: chainAsset.asset.name)
        self.scamInfo = scamInfo
    }

    func didReceive(searchResult: Result<[SearchData]?, Error>) {
        let viewModel = viewModelFactory.buildChooseRecipientTableViewModel(searchResult: searchResult)
        view?.didReceive(tableViewModel: viewModel)
    }
}

extension ChooseRecipientPresenter: WalletScanQRModuleOutput {
    func didFinishWith(payload: TransferPayload) {
        let chainFormat: ChainFormat = chainAsset.chain.isEthereumBased
            ? .ethereum
            : .substrate(chainAsset.chain.addressPrefix)

        guard let accountId = try? Data(hexString: payload.receiveInfo.accountId),
              let address = try? AddressFactory.address(for: accountId, chainFormat: chainFormat) else {
            return
        }

        router.presentSendAmount(
            from: view,
            to: address,
            chainAsset: chainAsset,
            wallet: wallet,
            scamInfo: scamInfo
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

extension ChooseRecipientPresenter: ContactsModuleOutput {
    func didSelect(address: String) {
        view?.didReceive(address: address)
        searchTextDidChanged(address)
    }
}
