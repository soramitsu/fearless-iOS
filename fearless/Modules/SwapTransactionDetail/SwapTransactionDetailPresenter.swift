import Foundation
import FearlessFoundation

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
    private var blockExplorer: ChainModel.ExternalApiExplorer?

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
            priceData: chainAsset.asset.getPrice(for: wallet.selectedCurrency),
            locale: selectedLocale
        )
        DispatchQueue.main.async {
            self.view?.didReceive(viewModel: viewModel)
        }
    }

    private func prepareBlockExplorer() {
        let blockExplorer = chainAsset.chain.externalApi?.explorers?.first(where: {
            $0.supportsTransactionLookup
        })
        view?.didReceive(explorer: blockExplorer)
        self.blockExplorer = blockExplorer
    }
}

// MARK: - SwapTransactionDetailViewOutput

extension SwapTransactionDetailPresenter: SwapTransactionDetailViewOutput {
    func didLoad(view: SwapTransactionDetailViewInput) {
        self.view = view
        interactor.setup(with: self)
        provideViewModel()
        prepareBlockExplorer()
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
              let blockExplorer = self.blockExplorer,
              let blockExplorerUrl = blockExplorer.explorerUrl(
                  for: transaction.transactionId,
                  type: blockExplorer.transactionType
              )
        else {
            return
        }

        router.showWeb(url: blockExplorerUrl, from: view, style: .automatic)
    }

    func didTapShare() {
        guard let blockExplorer = self.blockExplorer,
              let blockExplorerUrl = blockExplorer.explorerUrl(
                  for: transaction.transactionId,
                  type: blockExplorer.transactionType
              )
        else {
            return
        }
        router.share(sources: [blockExplorerUrl], from: view, with: nil)
    }
}

// MARK: - SwapTransactionDetailInteractorOutput

extension SwapTransactionDetailPresenter: SwapTransactionDetailInteractorOutput {}

// MARK: - Localizable

extension SwapTransactionDetailPresenter: Localizable {
    func applyLocalization() {}
}

extension SwapTransactionDetailPresenter: SwapTransactionDetailModuleInput {}
