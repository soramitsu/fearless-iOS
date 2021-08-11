import Foundation
import SoraFoundation

final class AnalyticsValidatorsPresenter {
    weak var view: AnalyticsValidatorsViewProtocol?
    private let wireframe: AnalyticsValidatorsWireframeProtocol
    private let interactor: AnalyticsValidatorsInteractorInputProtocol
    private let viewModelFactory: AnalyticsValidatorsViewModelFactoryProtocol
    private let localizationManager: LocalizationManager
    private let logger: LoggerProtocol?

    private var identitiesByAddress = [AccountAddress: AccountIdentity]()
    private var selectedPage: AnalyticsValidatorsPage = .activity
    private var eraValidatorInfos: [SQEraValidatorInfo]?
    private var stashItem: StashItem?
    private var nomination: Nomination?
    private var rewards: [SubqueryRewardItemData]?

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
        guard
            let eraValidatorInfos = eraValidatorInfos,
            let stashAddress = stashItem?.stash,
            let rewards = rewards,
            let nomination = nomination
        else { return }

        let viewModel = viewModelFactory.createViewModel(
            eraValidatorInfos: eraValidatorInfos,
            stashAddress: stashAddress,
            rewards: rewards,
            nomination: nomination,
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
            self.identitiesByAddress.merge(identitiesByAddress) { current, _ in current }
            updateView()
        case let .failure(error):
            logger?.error("Did receive identitiesByAddress error: \(error.localizedDescription)")
        }
    }

    func didReceive(eraValidatorInfosResult: Result<[SQEraValidatorInfo], Error>) {
        switch eraValidatorInfosResult {
        case let .success(eraValidatorInfos):
            self.eraValidatorInfos = eraValidatorInfos
            updateView()
        case let .failure(error):
            // TODO: handleError - retry
            logger?.error("Did receive eraValidatorInfos error: \(error.localizedDescription)")
        }
    }

    func didReceive(stashItemResult: Result<StashItem?, Error>) {
        switch stashItemResult {
        case let .success(stashItem):
            self.stashItem = stashItem
            updateView()
        case let .failure(error):
            logger?.error(error.localizedDescription)
        }
    }

    func didReceive(rewardsResult: Result<[SubqueryRewardItemData], Error>) {
        switch rewardsResult {
        case let .success(rewards):
            self.rewards = rewards
            updateView()
        case let .failure(error):
            // TODO: handleError - retry
            logger?.error(error.localizedDescription)
        }
    }

    func didReceive(nominationResult: Result<Nomination?, Error>) {
        switch nominationResult {
        case let .success(nomination):
            self.nomination = nomination
        case let .failure(error):
            logger?.error(error.localizedDescription)
        }
    }
}
