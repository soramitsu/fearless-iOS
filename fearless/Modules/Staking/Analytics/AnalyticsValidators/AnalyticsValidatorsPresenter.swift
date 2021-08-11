import Foundation
import SoraFoundation

final class AnalyticsValidatorsPresenter {
    weak var view: AnalyticsValidatorsViewProtocol?
    private let wireframe: AnalyticsValidatorsWireframeProtocol
    private let interactor: AnalyticsValidatorsInteractorInputProtocol
    private let viewModelFactory: AnalyticsValidatorsViewModelFactoryProtocol
    private let localizationManager: LocalizationManager
    private let logger: LoggerProtocol?

    private var identitiesByAddress: [AccountAddress: AccountIdentity]?
    private var selectedPage: AnalyticsValidatorsPage = .activity

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
        let viewModel = viewModelFactory.createViewModel(
            identitiesByAddress: identitiesByAddress,
            page: selectedPage
        )
        let localizedViewModel = viewModel.value(for: selectedLocale)
        view?.reload(viewState: .loaded(localizedViewModel))
    }
}

extension AnalyticsValidatorsPresenter: AnalyticsValidatorsPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func handleValidatorInfoAction(validatorAddress: AccountAddress) {
        wireframe.showValidatorInfo(address: validatorAddress, view: view)
    }

    func handlePageAction(page: AnalyticsValidatorsPage) {
        guard selectedPage != page else { return }
        selectedPage = page
        updateView()
    }
}

extension AnalyticsValidatorsPresenter: Localizable {
    func applyLocalization() {
        updateView()
    }
}

extension AnalyticsValidatorsPresenter: AnalyticsValidatorsInteractorOutputProtocol {
    func didReceive(identitiesByAddressResult: Result<[AccountAddress: AccountIdentity], Error>) {
        switch identitiesByAddressResult {
        case let .success(identitiesByAddress):
            self.identitiesByAddress = identitiesByAddress
            updateView()
        case let .failure(error):
            logger?.error("Did receive identitiesByAddress error: \(error.localizedDescription)")
        }
    }
}
