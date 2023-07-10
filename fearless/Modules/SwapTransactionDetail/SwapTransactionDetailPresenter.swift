import Foundation
import SoraFoundation
import CommonWallet
import SSFModels

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
    private var subscanExplorer: ChainModel.ExternalApiExplorer?

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

    private func prepareSubscanExplorer() {
        let subscanExplorer = chainAsset.chain.externalApi?.explorers?.first(where: {
            $0.type == .subscan
        })
        view?.didReceive(explorer: subscanExplorer)
        self.subscanExplorer = subscanExplorer
    }
}

// MARK: - SwapTransactionDetailViewOutput

extension SwapTransactionDetailPresenter: SwapTransactionDetailViewOutput {
    func didLoad(view: SwapTransactionDetailViewInput) {
        self.view = view
        interactor.setup(with: self)
        provideViewModel()
        prepareSubscanExplorer()
    }

    func didTapDismiss() {
        router.dismiss(view: view)
    }

    func didTapCopyTxHash() {
        UIPasteboard.general.string = transaction.transactionId
        let copyEvent = HashCopiedEvent(locale: selectedLocale)
        router.presentStatus(with: copyEvent, animated: true)
    }

    func didTapSubscan() {
        guard let view = view,
              let subscanExplorer = self.subscanExplorer,
              let subscanUrl = subscanExplorer.explorerUrl(for: transaction.transactionId, type: .extrinsic)
        else {
            return
        }

        router.showWeb(url: subscanUrl, from: view, style: .automatic)
    }

    func didTapShare() {
        guard let subscanExplorer = self.subscanExplorer,
              let subscanUrl = subscanExplorer.explorerUrl(for: transaction.transactionId, type: .extrinsic)
        else {
            return
        }
        router.share(sources: [subscanUrl], from: view, with: nil)
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
