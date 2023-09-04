import Foundation
import SoraFoundation
import SSFModels

final class AllDonePresenter {
    // MARK: Private properties

    private weak var view: AllDoneViewInput?
    private let router: AllDoneRouterInput
    private let interactor: AllDoneInteractorInput
    private let viewModelFactory: AllDoneViewModelFactoryProtocol

    private let chainAsset: ChainAsset?
    private let hashString: String?
    private var closure: (() -> Void)?

    private var title: String?
    private var description: String?

    private var subscanExplorer: ChainModel.ExternalApiExplorer?

    // MARK: - Constructors

    init(
        chainAsset: ChainAsset?,
        hashString: String?,
        interactor: AllDoneInteractorInput,
        router: AllDoneRouterInput,
        viewModelFactory: AllDoneViewModelFactoryProtocol,
        closure: (() -> Void)?,
        title: String? = nil,
        description: String? = nil,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.chainAsset = chainAsset
        self.hashString = hashString
        self.interactor = interactor
        self.router = router
        self.viewModelFactory = viewModelFactory
        self.closure = closure
        self.title = title
        self.description = description
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideViewModel() {
        let viewModel = viewModelFactory.buildViewModel(
            title: title,
            description: description,
            extrinsicHash: hashString,
            locale: selectedLocale
        )

        view?.didReceive(viewModel: viewModel)
    }

    private func prepareSubscanExplorer() {
        let subscanExplorer = chainAsset?.chain.externalApi?.explorers?.first(where: {
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
        provideViewModel()
        prepareSubscanExplorer()
    }

    func subscanButtonDidTapped() {
        guard let subscanExplorer = self.subscanExplorer,
              let hashString = hashString,
              let subscanUrl = subscanExplorer.explorerUrl(for: hashString, type: .extrinsic)
        else {
            return
        }
        router.presentSubscan(from: view, url: subscanUrl)
    }

    func shareButtonDidTapped() {
        guard let subscanExplorer = self.subscanExplorer,
              let hashString = hashString,
              let subscanUrl = subscanExplorer.explorerUrl(for: hashString, type: .extrinsic)
        else {
            return
        }
        router.share(sources: [subscanUrl], from: view, with: nil)
    }

    func dismiss() {
        router.dismiss(view: view)
    }

    func didCopyTapped() {
        let copyEvent = HashCopiedEvent(locale: selectedLocale)
        router.presentStatus(with: copyEvent, animated: true)
    }

    func presentationControllerWillDismiss() {
        closure?()
    }
}

// MARK: - AllDoneInteractorOutput

extension AllDonePresenter: AllDoneInteractorOutput {}

// MARK: - Localizable

extension AllDonePresenter: Localizable {
    func applyLocalization() {
        provideViewModel()
    }
}

extension AllDonePresenter: AllDoneModuleInput {}
