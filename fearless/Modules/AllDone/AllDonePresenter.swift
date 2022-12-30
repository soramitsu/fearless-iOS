import Foundation
import SoraFoundation

final class AllDonePresenter {
    // MARK: Private properties

    private weak var view: AllDoneViewInput?
    private let router: AllDoneRouterInput
    private let interactor: AllDoneInteractorInput

    private let chainAsset: ChainAsset
    private let hashString: String

    private var subscanExplorer: ChainModel.ExternalApiExplorer?

    // MARK: - Constructors

    init(
        chainAsset: ChainAsset,
        hashString: String,
        interactor: AllDoneInteractorInput,
        router: AllDoneRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.chainAsset = chainAsset
        self.hashString = hashString
        self.interactor = interactor
        self.router = router
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideHashString() {
        view?.didReceive(hashString: hashString)
    }

    private func prepareSubscanExplorer() {
        let subscanExplorer = chainAsset.chain.externalApi?.explorers?.first(where: {
            $0.type == .subscan
        })
        view?.didReceive(explorer: subscanExplorer)
        self.subscanExplorer = subscanExplorer
    }
}

// MARK: - AllDoneViewOutput

extension AllDonePresenter: AllDoneViewOutput {
    func didLoad(view: AllDoneViewInput) {
        self.view = view
        interactor.setup(with: self)
        provideHashString()
        prepareSubscanExplorer()
    }

    func subscanButtonDidTapped() {
        guard let subscanExplorer = self.subscanExplorer,
              let subscanUrl = subscanExplorer.explorerUrl(for: hashString, type: .extrinsic)
        else {
            return
        }
        router.presentSubscan(from: view, url: subscanUrl)
    }

    func shareButtonDidTapped() {
        let source = TextSharingSource(message: hashString)
        router.share(source: source, from: view, with: nil)
    }
}

// MARK: - AllDoneInteractorOutput

extension AllDonePresenter: AllDoneInteractorOutput {
    func dismiss() {
        router.dismiss(view: view)
    }

    func didCopyTapped() {
        let copyEvent = HashCopiedEvent(locale: selectedLocale)
        router.presentStatus(with: copyEvent, animated: true)
    }
}

// MARK: - Localizable

extension AllDonePresenter: Localizable {
    func applyLocalization() {
        provideHashString()
    }
}

extension AllDonePresenter: AllDoneModuleInput {}
