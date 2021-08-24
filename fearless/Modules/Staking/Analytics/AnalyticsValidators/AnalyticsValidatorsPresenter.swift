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
    private var eraValidatorInfos: [SubqueryEraValidatorInfo]?
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
        view?.reload(viewState: .loading)
        interactor.setup()
    }

    func reload() {
        view?.reload(viewState: .loading)
        if let stash = stashItem?.stash {
            interactor.fetchRewards(stashAddress: stash)
        }
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
            self.identitiesByAddress.merge(identitiesByAddress) { _, new in new }
            updateView()
        case let .failure(error):
            logger?.error("Did receive identitiesByAddress error: \(error.localizedDescription)")
        }
    }

    func didReceive(eraValidatorInfosResult: Result<[SubqueryEraValidatorInfo], Error>) {
        switch eraValidatorInfosResult {
        case let .success(eraValidatorInfos):
            self.eraValidatorInfos = eraValidatorInfos
            updateView()
        case let .failure(error):
            let errorText = R.string.localizable.commonErrorNoDataRetrieved(
                preferredLanguages: selectedLocale.rLanguages
            )
            view?.reload(viewState: .error(errorText))
            logger?.error("Did receive eraValidatorInfos error: \(error.localizedDescription)")
        }
    }

    func didReceive(stashItemResult: Result<StashItem?, Error>) {
        switch stashItemResult {
        case let .success(stashItem):
            self.stashItem = stashItem
            if let stash = stashItem?.stash {
                interactor.fetchRewards(stashAddress: stash)
            }
        case let .failure(error):
            logger?.error("Did receive stashItem error: \(error)")
        }
    }

    func didReceive(rewardsResult: Result<[SubqueryRewardItemData], Error>) {
        switch rewardsResult {
        case let .success(rewards):
            self.rewards = rewards
            updateView()
        case let .failure(error):
            let errorText = R.string.localizable.commonErrorNoDataRetrieved(
                preferredLanguages: selectedLocale.rLanguages
            )
            view?.reload(viewState: .error(errorText))
            logger?.error("Did receive rewards error: \(error.localizedDescription)")
        }
    }

    func didReceive(nominationResult: Result<Nomination?, Error>) {
        switch nominationResult {
        case let .success(nomination):
            self.nomination = nomination
        case let .failure(error):
            logger?.error("Did receive nomination error: \(error.localizedDescription)")
        }
    }
}
