import Foundation
import SoraFoundation

final class ChainAccountPresenter {
    weak var view: ChainAccountViewProtocol?
    let wireframe: ChainAccountWireframeProtocol
    let interactor: ChainAccountInteractorInputProtocol
    let viewModelFactory: ChainAccountViewModelFactoryProtocol
    let logger: LoggerProtocol
    let asset: AssetModel
    let chain: ChainModel
    let selectedMetaAccount: MetaAccountModel

    private var accountInfo: AccountInfo?
    private var priceData: PriceData?

    init(
        interactor: ChainAccountInteractorInputProtocol,
        wireframe: ChainAccountWireframeProtocol,
        viewModelFactory: ChainAccountViewModelFactoryProtocol,
        logger: LoggerProtocol,
        asset: AssetModel,
        chain: ChainModel,
        selectedMetaAccount: MetaAccountModel
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.logger = logger
        self.asset = asset
        self.chain = chain
        self.selectedMetaAccount = selectedMetaAccount
    }

    func provideViewModel() {
        let accountBalanceViewModel = viewModelFactory.buildAccountBalanceViewModel(
            accountInfo: accountInfo,
            priceData: priceData,
            asset: asset,
            locale: selectedLocale
        )

        let assetInfoViewModel = viewModelFactory.buildAssetInfoViewModel(
            chain: chain,
            assetModel: asset,
            priceData: priceData,
            locale: selectedLocale
        )

        let chainAccountViewModel = viewModelFactory.buildChainAccountViewModel(
            accountBalanceViewModel: accountBalanceViewModel,
            assetInfoViewModel: assetInfoViewModel
        )

        view?.didReceiveState(.loaded(chainAccountViewModel))
    }
}

extension ChainAccountPresenter: ChainAccountPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func didTapBackButton() {
        wireframe.close(view: view)
    }

    func didTapSendButton() {
        wireframe.presentSendFlow(
            from: view,
            asset: asset,
            chain: chain,
            selectedMetaAccount: selectedMetaAccount
        )
    }

    func didTapReceiveButton() {
        wireframe.presentReceiveFlow(
            from: view,
            asset: asset,
            chain: chain,
            selectedMetaAccount: selectedMetaAccount
        )
    }

    func didTapBuyButton() {}
}

extension ChainAccountPresenter: ChainAccountInteractorOutputProtocol {
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for _: ChainModel.Id) {
        switch result {
        case let .success(accountInfo):
            self.accountInfo = accountInfo
            provideViewModel()
        case let .failure(error):
            logger.error("ChainAccountPresenter:didReceiveAccountInfo:error:\(error)")
        }
    }

    func didReceivePriceData(result: Result<PriceData?, Error>, for _: AssetModel.PriceId) {
        switch result {
        case let .success(priceData):
            if priceData != nil {
                self.priceData = priceData
                provideViewModel()
            }
        case let .failure(error):
            logger.error("ChainAccountPresenter:didReceivePriceData:error:\(error)")
        }
    }
}

extension ChainAccountPresenter: Localizable {
    func applyLocalization() {
        provideViewModel()
    }
}
