import Foundation
import SoraFoundation
import CommonWallet

final class SwapTransactionDetailPresenter {
    // MARK: Private properties

    private weak var view: SwapTransactionDetailViewInput?
    private let router: SwapTransactionDetailRouterInput
    private let interactor: SwapTransactionDetailInteractorInput
    private let viewModelFactory: SwapTransactionViewModelFactoryProtocol

    private let wallet: MetaAccountModel
    private let chainAsset: ChainAsset
    private let transaction: AssetTransactionData
    private var priceData: PriceData?

    // MARK: - Constructors

    init(
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        transaction: AssetTransactionData,
        viewModelFactory: SwapTransactionViewModelFactoryProtocol,
        interactor: SwapTransactionDetailInteractorInput,
        router: SwapTransactionDetailRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.wallet = wallet
        self.chainAsset = chainAsset
        self.transaction = transaction
        self.viewModelFactory = viewModelFactory
        self.interactor = interactor
        self.router = router
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideViewModel() {
        let viewModel = viewModelFactory.createViewModel(
            wallet: wallet,
            chainAsset: chainAsset,
            transaction: transaction,
            priceData: priceData,
            locale: selectedLocale
        )
        DispatchQueue.main.async {
            self.view?.didReceive(viewModel: viewModel)
        }
    }
}

// MARK: - SwapTransactionDetailViewOutput

extension SwapTransactionDetailPresenter: SwapTransactionDetailViewOutput {
    func didLoad(view: SwapTransactionDetailViewInput) {
        self.view = view
        interactor.setup(with: self)
        provideViewModel()
    }

    func didTapDismiss() {
        router.dismiss(view: view)
    }
}

// MARK: - SwapTransactionDetailInteractorOutput

extension SwapTransactionDetailPresenter: SwapTransactionDetailInteractorOutput {
    func didReceive(priceData: PriceData?) {
        self.priceData = priceData
        provideViewModel()
    }
}

// MARK: - Localizable

extension SwapTransactionDetailPresenter: Localizable {
    func applyLocalization() {}
}

extension SwapTransactionDetailPresenter: SwapTransactionDetailModuleInput {}
