import Foundation
import CommonWallet
import SoraFoundation
import IrohaCrypto

final class SearchPeoplePresenter {
    weak var view: SearchPeopleViewProtocol?
    private let wireframe: SearchPeopleWireframeProtocol
    private let interactor: SearchPeopleInteractorInputProtocol
    private let viewModelFactory: SearchPeopleViewModelFactoryProtocol
    private let chainAsset: ChainAsset
    private let wallet: MetaAccountModel
    private let qrParser: QRParser
    private let transferFinishBlock: WalletTransferFinishBlock?
    private let scamInfo: ScamInfo?

    private var searchResult: Result<[SearchData]?, Error>?

    init(
        interactor: SearchPeopleInteractorInputProtocol,
        wireframe: SearchPeopleWireframeProtocol,
        viewModelFactory: SearchPeopleViewModelFactoryProtocol,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        localizationManager: LocalizationManagerProtocol,
        qrParser: QRParser,
        scamInfo: ScamInfo?,
        transferFinishBlock: WalletTransferFinishBlock?
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.qrParser = qrParser
        self.scamInfo = scamInfo
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
        wireframe.presentScan(
            from: view,
            chainAsset: chainAsset,
            wallet: wallet,
            moduleOutput: self
        )
    }

    func searchTextDidChanged(_ text: String) {
        interactor.performSearch(query: text)
    }

    func setup() {
        view?.didReceive(title: R.string.localizable.walletSendNavigationTitle(
            chainAsset.asset.name,
            preferredLanguages: selectedLocale.rLanguages
        ))
        view?.didReceive(locale: selectedLocale)
    }

    func didSelectViewModel(viewModel: SearchPeopleTableCellViewModel) {
        wireframe.presentSend(
            from: view,
            to: viewModel.address,
            chainAsset: chainAsset,
            wallet: wallet,
            scamInfo: scamInfo,
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
        let chainFormat: ChainFormat = chainAsset.chain.isEthereumBased
            ? .ethereum
            : .substrate(chainAsset.chain.addressPrefix)

        guard let accountId = try? Data(hexString: payload.receiveInfo.accountId),
              let address = try? AddressFactory.address(for: accountId, chainFormat: chainFormat) else {
            return
        }

        wireframe.presentSend(
            from: view,
            to: address,
            chainAsset: chainAsset,
            wallet: wallet,
            scamInfo: scamInfo,
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
