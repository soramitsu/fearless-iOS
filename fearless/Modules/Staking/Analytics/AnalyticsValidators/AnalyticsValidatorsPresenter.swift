import Foundation
import SoraFoundation

final class AnalyticsValidatorsPresenter {
    weak var view: AnalyticsValidatorsViewProtocol?
    private let wireframe: AnalyticsValidatorsWireframeProtocol
    private let interactor: AnalyticsValidatorsInteractorInputProtocol
    private let viewModelFactory: AnalyticsValidatorsViewModelFactoryProtocol
    private let localizationManager: LocalizationManager
    private let logger: LoggerProtocol?

    init(
        interactor: AnalyticsValidatorsInteractorInputProtocol,
        wireframe: AnalyticsValidatorsWireframeProtocol,
        viewModelFactory: AnalyticsValidatorsViewModelFactoryProtocol,
        localizationManager: LocalizationManager,
        logger: LoggerProtocol? = nil
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.localizationManager = localizationManager
        self.logger = logger
    }

    private func updateView() {
        let viewModel = viewModelFactory.createViewModel()
        let localizedViewModel = viewModel.value(for: selectedLocale)
        view?.reload(viewState: .loaded(localizedViewModel))
    }
}

extension AnalyticsValidatorsPresenter: AnalyticsValidatorsPresenterProtocol {
    func setup() {
        // TODO:
        updateView()
    }

    func handleValidatorInfoAction(validatorAddress: AccountAddress) {
        wireframe.showValidatorInfo(address: validatorAddress, view: view)
    }
}

extension AnalyticsValidatorsPresenter: Localizable {
    func applyLocalization() {
        updateView()
    }
}

extension AnalyticsValidatorsPresenter: AnalyticsValidatorsInteractorOutputProtocol {}
