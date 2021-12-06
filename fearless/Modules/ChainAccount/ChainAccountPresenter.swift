import Foundation
import SoraFoundation

final class ChainAccountPresenter {
    weak var view: ChainAccountViewProtocol?
    let wireframe: ChainAccountWireframeProtocol
    let interactor: ChainAccountInteractorInputProtocol
    let viewModelFactory: ChainAccountViewModelFactoryProtocol
    let logger: LoggerProtocol
    let asset: AssetModel

    private var accountInfo: AccountInfo?
    private var priceData: PriceData?

    init(
        interactor: ChainAccountInteractorInputProtocol,
        wireframe: ChainAccountWireframeProtocol,
        viewModelFactory: ChainAccountViewModelFactoryProtocol,
        logger: LoggerProtocol,
        asset: AssetModel
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.logger = logger
        self.asset = asset
    }

    func provideViewModel() {
        let accountBalanceViewModel = viewModelFactory.buildAccountBalanceViewModel(
            accountInfo: accountInfo,
            priceData: priceData,
            asset: asset,
            locale: selectedLocale
        )

        let chainAccountViewModel = viewModelFactory.buildChainAccountViewModel(accountBalanceViewModel: accountBalanceViewModel)

        view?.didReceiveState(.loaded(chainAccountViewModel))
    }
}

extension ChainAccountPresenter: ChainAccountPresenterProtocol {
    func setup() {
        interactor.setup()
    }
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
            self.priceData = priceData
            provideViewModel()
        case let .failure(error):
            logger.error("ChainAccountPresenter:didReceivePriceData:error:\(error)")
        }
    }
}

extension ChainAccountPresenter: Localizable {
    func applyLocalization() {
        if let view = view {
            provideViewModel()
        }
    }
}
