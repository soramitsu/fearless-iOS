import Foundation
import SoraFoundation

final class KYCMainPresenter {
    // MARK: Private properties

    private weak var view: KYCMainViewInput?
    private let router: KYCMainRouterInput
    private let interactor: KYCMainInteractorInput
    private let viewModelFactory: KYCMainViewModelFactoryProtocol
    private var xorChainAssets: [ChainAsset] = []

    // MARK: - Constructors

    init(
        interactor: KYCMainInteractorInput,
        router: KYCMainRouterInput,
        viewModelFactory: KYCMainViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.router = router
        self.viewModelFactory = viewModelFactory
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func showMoreXorSources(for chainAsset: ChainAsset) {
        let languages = localizationManager?.selectedLocale.rLanguages
        let swapAction = SheetAlertPresentableAction(
            title: R.string.localizable.getMoreXorSwapActionTitle(preferredLanguages: languages)
        ) { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.router.showSwap(from: strongSelf.view, wallet: strongSelf.interactor.wallet, chainAsset: chainAsset)
        }

        let buyAction = SheetAlertPresentableAction(
            title: R.string.localizable.getMoreXorBuyActionTitle(preferredLanguages: languages),
            style: .warningStyle
        ) { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.router.showBuyXor(from: strongSelf.view, wallet: strongSelf.interactor.wallet, chainAsset: chainAsset)
        }

        let viewModel = SheetAlertPresentableViewModel(
            title: R.string.localizable.detailsGetMoreXor(preferredLanguages: languages),
            message: R.string.localizable.detailsGetMoreXorDescription(preferredLanguages: languages),
            actions: [buyAction, swapAction],
            closeAction: nil,
            icon: R.image.iconWarningBig()
        )

        DispatchQueue.main.async { [weak self] in
            self?.router.present(viewModel: viewModel, from: self?.view)
        }
    }
}

// MARK: - KYCMainViewOutput

extension KYCMainPresenter: KYCMainViewOutput {
    func didTapIssueCardForFree() {
        interactor.checkUserStatus()
    }

    func didTapGetMoreXor() {
        if xorChainAssets.count > 1 {
            let chains = xorChainAssets.map { $0.chain }
            router.showSelectNetwork(
                from: view,
                wallet: interactor.wallet,
                chainModels: chains,
                delegate: self
            )
        } else {
            guard let chainAsset = xorChainAssets.first else { return }
            showMoreXorSources(for: chainAsset)
        }
    }

    func didTapIssueCard() {
//        TODO: Phase2: 12$ pay integration"
    }

    func didTapUnsupportedCountriesList() {
        guard let url = ApplicationConfig().soraCardCountriesBlacklist, let view = view else {
            return
        }

        router.showWeb(url: url, from: view, style: .automatic)
    }

    func didTapHaveCard() {
        router.showTermsAndConditions(from: view)
    }

    func didLoad(view: KYCMainViewInput) {
        self.view = view
        view.updateHaveCardButton(isHidden: SCStorage.shared.hasToken())
        interactor.setup(with: self)
    }

    func willDisappear() {
        interactor.prepareToDismiss()
    }
}

// MARK: - KYCMainInteractorOutput

extension KYCMainPresenter: KYCMainInteractorOutput {
    func didReceive(data: KYCMainData) {
        let viewModel = viewModelFactory.buildViewModel(from: data, locale: selectedLocale)
        view?.set(viewModel: viewModel)
    }

    func didReceive(xorChainAssets: [ChainAsset]) {
        self.xorChainAssets = xorChainAssets
    }

    func didReceiveFinalStatus() {
        router.dismiss(view: view)
    }

    func showFullFlow() {
        router.showTermsAndConditions(from: view)
    }

    func showGetPrepared(data: SCKYCUserDataModel) {
        router.showGetPrepared(from: view, data: data)
    }

    func showStatus() {
        router.showStatus(from: view)
    }
}

// MARK: - Localizable

extension KYCMainPresenter: Localizable {
    func applyLocalization() {}
}

extension KYCMainPresenter: KYCMainModuleInput {}

extension KYCMainPresenter: SelectNetworkDelegate {
    func chainSelection(view _: SelectNetworkViewInput, didCompleteWith chain: ChainModel?, contextTag _: Int?) {
        if let chainAsset = xorChainAssets.first(where: { $0.chain == chain }) {
            showMoreXorSources(for: chainAsset)
        }
    }
}
