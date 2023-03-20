import Foundation
import SoraFoundation

final class KYCMainPresenter {
    // MARK: Private properties

    private weak var view: KYCMainViewInput?
    private let router: KYCMainRouterInput
    private let interactor: KYCMainInteractorInput
    private let viewModelFactory: KYCMainViewModelFactoryProtocol

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
}

// MARK: - KYCMainViewOutput

extension KYCMainPresenter: KYCMainViewOutput {
    func didTapIssueCardForFree() {
        router.showTermsAndConditions(from: view)
    }

    func didTapGetMoreXor() {
        let languages = localizationManager?.selectedLocale.rLanguages

        let swapAction = SheetAlertPresentableAction(
            title: R.string.localizable.getMoreXorSwapActionTitle(preferredLanguages: languages),
            style: .warningStyle
        ) { [weak self] in
            guard let self = self, let chainAsset = self.interactor.xorChainAsset else { return }
            self.router.showSwap(from: self.view, wallet: self.interactor.wallet, chainAsset: chainAsset)
        }

        let buyAction = SheetAlertPresentableAction(
            title: R.string.localizable.getMoreXorBuyActionTitle(preferredLanguages: languages)
        ) { [weak self] in
            guard let self = self, let chainAsset = self.interactor.xorChainAsset else { return }
            self.router.showBuyXor(from: self.view, wallet: self.interactor.wallet, chainAsset: chainAsset)
        }

        let viewModel = SheetAlertPresentableViewModel(
            title: R.string.localizable.detailsGetMoreXor(preferredLanguages: languages),
            message: R.string.localizable.detailsGetMoreXorDescription(preferredLanguages: languages),
            actions: [swapAction, buyAction],
            closeAction: nil,
            icon: R.image.iconWarningBig()
        )

        DispatchQueue.main.async { [weak self] in
            self?.router.present(viewModel: viewModel, from: self?.view)
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
}

// MARK: - Localizable

extension KYCMainPresenter: Localizable {
    func applyLocalization() {}
}

extension KYCMainPresenter: KYCMainModuleInput {}
