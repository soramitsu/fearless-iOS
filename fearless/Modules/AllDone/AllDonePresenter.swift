import Foundation
import SoraFoundation

final class AllDonePresenter {
    // MARK: Private properties

    private weak var view: AllDoneViewInput?
    private let router: AllDoneRouterInput
    private let interactor: AllDoneInteractorInput
    private let viewModelFactory: AllDoneViewModelFactoryProtocol

    private let hashString: String
    private var closure: (() -> Void)?

    private var title: String?
    private var description: String?

    // MARK: - Constructors

    init(
        hashString: String,
        interactor: AllDoneInteractorInput,
        router: AllDoneRouterInput,
        viewModelFactory: AllDoneViewModelFactoryProtocol,
        closure: (() -> Void)?,
        title: String? = nil,
        description: String? = nil,
        localizationManager: LocalizationManagerProtocol
    ) {
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
}

// MARK: - AllDoneViewOutput

extension AllDonePresenter: AllDoneViewOutput {
    func didLoad(view: AllDoneViewInput) {
        self.view = view
        interactor.setup(with: self)
        provideViewModel()
    }
}

// MARK: - AllDoneInteractorOutput

extension AllDonePresenter: AllDoneInteractorOutput {
    func dismiss() {
        closure?()
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
        provideViewModel()
    }
}

extension AllDonePresenter: AllDoneModuleInput {}
