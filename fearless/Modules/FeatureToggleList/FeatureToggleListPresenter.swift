import Foundation
import SoraFoundation

protocol FeatureToggleListViewInput: ControllerBackedProtocol {
    func didReceive(viewModels: [SelectableViewModel<TitleWithSubtitleViewModel>])
}

protocol FeatureToggleListInteractorInput: AnyObject {
    var toggles: [LocalListToggle] { get }
    func setup(with output: FeatureToggleListInteractorOutput)
    func set(toggle: LocalListToggle)
}

final class FeatureToggleListPresenter {
    // MARK: Private properties
    private weak var view: FeatureToggleListViewInput?
    private let router: FeatureToggleListRouterInput
    private let interactor: FeatureToggleListInteractorInput

    // MARK: - Constructors
    init(
        interactor: FeatureToggleListInteractorInput,
        router: FeatureToggleListRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.router = router
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideToggles() {
        Task {
            let toggles = interactor.toggles
            let viewModels = toggles.map {
                let underlyingViewModel = TitleWithSubtitleViewModel(
                    title: $0.title,
                    subtitle: $0.description
                )
                return SelectableViewModel(
                    underlyingViewModel: underlyingViewModel,
                    selectable: $0.storageValue
                )
            }
            Task { @MainActor in
                view?.didReceive(viewModels: viewModels)
            }
        }
    }
}

// MARK: - FeatureToggleListViewOutput
extension FeatureToggleListPresenter: FeatureToggleListViewOutput {
    func didSwitch(index: Int) {
        guard var toggle = interactor.toggles[safe: index] else {
            return
        }
        let updatedToggle = toggle.toggle()
        interactor.set(toggle: updatedToggle)
    }

    func didLoad(view: FeatureToggleListViewInput) {
        self.view = view
        interactor.setup(with: self)
        provideToggles()
    }
}

// MARK: - FeatureToggleListInteractorOutput
extension FeatureToggleListPresenter: FeatureToggleListInteractorOutput {}

// MARK: - Localizable
extension FeatureToggleListPresenter: Localizable {
    func applyLocalization() {}
}

extension FeatureToggleListPresenter: FeatureToggleListModuleInput {}
