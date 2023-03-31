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

    func showCIKeys() {
        DispatchQueue.main.async { [weak self] in
            self?.router.present(message: "SC api: \(SoraCardCIKeys.apiKey), SC domain: \(SoraCardCIKeys.domain), SC endpoint: \(SoraCardCIKeys.endpoint), SC username: \(SoraCardCIKeys.username), SC password: \(SoraCardCIKeys.password), PW  url: \(PayWingsCIKeys.repositoryUrl), PW username: \(PayWingsCIKeys.username), PW password: \(PayWingsCIKeys.password), X1 endpointRelease: \(XOneCIKeys.endpointRelease), X1 widgetRelease: \(XOneCIKeys.widgetRelease), X1 endpointDebug: \(XOneCIKeys.endpointDebug), X1 widgetDebug: \(XOneCIKeys.widgetDebug)", title: "CI Keys", closeAction: nil, from: self?.view, actions: [])
        }
    }
}

// MARK: - KYCMainViewOutput

extension KYCMainPresenter: KYCMainViewOutput {
    func didTapIssueCardForFree() {
        router.showTermsAndConditions(from: view)
    }

    func didTapGetMoreXor() {
        guard let chainAsset = interactor.xorChainAssets.first(where: { chainAsset in
            chainAsset.chain.chainId == Chain.soraMain.genesisHash
        }) else { return }

        let languages = localizationManager?.selectedLocale.rLanguages
        let swapAction = SheetAlertPresentableAction(
            title: R.string.localizable.getMoreXorSwapActionTitle(preferredLanguages: languages),
            style: .warningStyle
        ) { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.router.showSwap(from: strongSelf.view, wallet: strongSelf.interactor.wallet, chainAsset: chainAsset)
        }

        let buyAction = SheetAlertPresentableAction(
            title: R.string.localizable.getMoreXorBuyActionTitle(preferredLanguages: languages)
        ) { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.router.showBuyXor(from: strongSelf.view, wallet: strongSelf.interactor.wallet, chainAsset: chainAsset)
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
        showCIKeys()
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
