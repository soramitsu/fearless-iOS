import Foundation
import SoraFoundation
import SoraKeystore

final class EducationStoriesPresenter {
    // MARK: Private properties

    private weak var view: EducationStoriesViewProtocol?
    private let router: EducationStoriesRouterProtocol
    private let interactor: EducationStoriesInteractorInput

    private let storiesFactory: EducationStoriesFactory
    private let startViewHelper: StartViewHelperProtocol

    // MARK: - Constructors

    init(
        interactor: EducationStoriesInteractorInput,
        storiesFactory: EducationStoriesFactory,
        router: EducationStoriesRouterProtocol,
        startViewHelper: StartViewHelperProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.storiesFactory = storiesFactory
        self.router = router
        self.startViewHelper = startViewHelper
        self.localizationManager = localizationManager
    }

    private func loadSlides() {
        let slides = createNewsVersion2Stories()
        let state = EducationStoriesViewState.loaded(slides)
        view?.didReceive(state: state)
    }

    private func createNewsVersion2Stories() -> [EducationSlideView] {
        let slides = storiesFactory.createNewsVersion2Stories(for: selectedLocale)
        return slides
    }
}

// MARK: - EducationStoriesPresenterProtocol

extension EducationStoriesPresenter: EducationStoriesPresenterProtocol {
    func didLoad(view: EducationStoriesViewProtocol) {
        self.view = view
        interactor.setup(with: self)

        loadSlides()
    }

    func didCloseStories() {
        interactor.didCloseStories()

        switch startViewHelper.startView() {
        case .pin:
            router.showLocalAuthentication()
        case .pinSetup:
            router.showPincodeSetup()
        case .login:
            router.showOnboarding()
        case .onboarding, .broken:
            break
        }
    }
}

extension EducationStoriesPresenter: EducationStoriesInteractorOutput {}

// MARK: - Localizable

extension EducationStoriesPresenter: Localizable {
    func applyLocalization() {
        loadSlides()
    }
}
