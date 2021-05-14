import Foundation
import RobinHood

final class RecommendedValidatorsPresenter {
    weak var view: RecommendedValidatorsViewProtocol?
    var wireframe: RecommendedValidatorsWireframeProtocol!
    var interactor: RecommendedValidatorsInteractorInputProtocol!

    let logger: LoggerProtocol?

    var allValidators: [ElectedValidatorInfo]?
    var recommended: [ElectedValidatorInfo]?

    let recommendationsComposer: RecommendationsComposing

    init(recommendationsComposer: RecommendationsComposing, logger: LoggerProtocol? = nil) {
        self.recommendationsComposer = recommendationsComposer
        self.logger = logger
    }

    private func updateView() {
        guard let all = allValidators, let recommended = recommended else {
            return
        }

        let totalCount = min(all.count, StakingConstants.maxTargets)
        let viewModel = RecommendedViewModel(
            selectedCount: recommended.count,
            totalCount: totalCount
        )

        view?.didReceive(viewModel: viewModel)
    }
}

extension RecommendedValidatorsPresenter: RecommendedValidatorsPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func proceed() {
        guard let all = allValidators, let recommended = recommended else {
            return
        }

        let totalCount = min(all.count, StakingConstants.maxTargets)

        let targets = recommended.map {
            SelectedValidatorInfo(
                address: $0.address,
                identity: $0.identity,
                stakeInfo: ValidatorStakeInfo(
                    nominators: $0.nominators,
                    totalStake: $0.totalStake,
                    stakeReturn: $0.stakeReturn,
                    maxNominatorsRewarded: $0.maxNominatorsRewarded
                )
            )
        }

        wireframe.proceed(from: view, targets: targets, maxTargets: totalCount)
    }

    func selectRecommendedValidators() {
        guard let all = allValidators, let recommended = recommended else {
            return
        }

        let totalCount = min(all.count, StakingConstants.maxTargets)

        wireframe.showRecommended(from: view, validators: recommended, maxTargets: totalCount)
    }

    func selectCustomValidators() {
        guard let all = allValidators else {
            return
        }

        wireframe.showCustom(from: view, validators: all)
    }
}

extension RecommendedValidatorsPresenter: RecommendedValidatorsInteractorOutputProtocol {
    func didReceive(validators: [ElectedValidatorInfo]) {
        allValidators = validators

        recommended = recommendationsComposer.compose(from: validators)

        updateView()
    }

    func didReceive(error: Error) {
        logger?.error("Did receive error \(error)")

        let locale = view?.localizationManager?.selectedLocale
        if !wireframe.present(error: error, from: view, locale: locale) {
            _ = wireframe.present(
                error: BaseOperationError.unexpectedDependentResult,
                from: view,
                locale: locale
            )
        }
    }
}
