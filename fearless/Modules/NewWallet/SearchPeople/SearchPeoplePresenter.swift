import Foundation
import CommonWallet
import SoraFoundation
import IrohaCrypto

final class SearchPeoplePresenter {
    weak var view: SearchPeopleViewProtocol?
    let wireframe: SearchPeopleWireframeProtocol
    let interactor: SearchPeopleInteractorInputProtocol
    let viewModelFactory: SearchPeopleViewModelFactoryProtocol
    let asset: AssetModel
    let chain: ChainModel
    let selectedAccount: MetaAccountModel
    let qrParser: QRParser
    let transferFinishBlock: WalletTransferFinishBlock?

    private var searchResult: Result<[SearchData]?, Error>?

    init(
        interactor: SearchPeopleInteractorInputProtocol,
        wireframe: SearchPeopleWireframeProtocol,
        viewModelFactory: SearchPeopleViewModelFactoryProtocol,
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

    private func provideViewModel() {
        switch searchResult {
        case let .success(searchData):
            guard let searchData = searchData, !searchData.isEmpty else {
                view?.didReceive(state: .empty)
                return
            }

            let viewModel = viewModelFactory.buildSearchPeopleViewModel(results: searchData)
            view?.didReceive(state: .loaded(viewModel))
        case let .failure(error):
            view?.didReceive(state: .error(error))
        case .none:
            view?.didReceive(state: .empty)
        }
    }
}

extension SearchPeoplePresenter: SearchPeoplePresenterProtocol {
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

    func searchTextDidChanged(_ text: String) {
        interactor.performSearch(query: text)
    }

    func setup() {
        view?.didReceive(title: R.string.localizable.walletSendNavigationTitle(
            asset.name,
            preferredLanguages: selectedLocale.rLanguages
        ))
        view?.didReceive(locale: selectedLocale)
    }

    func didSelectViewModel(viewModel: SearchPeopleTableCellViewModel) {
        wireframe.presentSend(
            from: view,
            to: viewModel.address,
            asset: asset,
            chain: chain,
            wallet: selectedAccount,
            transferFinishBlock: transferFinishBlock
        )
    }
}

extension SearchPeoplePresenter: SearchPeopleInteractorOutputProtocol {
    func didReceive(searchResult: Result<[SearchData]?, Error>) {
        self.searchResult = searchResult
        provideViewModel()
    }
}

extension SearchPeoplePresenter: Localizable {
    func applyLocalization() {
        view?.didReceive(locale: selectedLocale)
    }
}

extension SearchPeoplePresenter: WalletScanQRModuleOutput {
    func didFinishWith(payload: TransferPayload) {
        let chainFormat: ChainFormat = chain.isEthereumBased
            ? .ethereum
            : .substrate(chain.addressPrefix)

        guard let accountId = try? Data(hexString: payload.receiveInfo.accountId),
              let address = try? AddressFactory.address(for: accountId, chainFormat: chainFormat) else {
            return
        }

        wireframe.presentSend(
            from: view,
            to: address,
            asset: asset,
            chain: chain,
            wallet: selectedAccount,
            transferFinishBlock: transferFinishBlock
        )
    }

    func didFinishWith(incorrectAddress: String) {
        guard let code = try? qrParser.extractAddress(from: incorrectAddress) else {
            return
        }

        view?.didReceive(input: code)
        searchTextDidChanged(code)
    }
}
