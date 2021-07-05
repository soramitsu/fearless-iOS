import Foundation
import RobinHood

final class SelectValidatorsStartPresenter {
    weak var view: SelectValidatorsStartViewProtocol?
    var wireframe: SelectValidatorsStartWireframeProtocol!
    var interactor: SelectValidatorsStartInteractorInputProtocol!

    let logger: LoggerProtocol?

    var allValidators: [ElectedValidatorInfo]?
    var recommended: [ElectedValidatorInfo]?

    let recommendationsComposer: RecommendationsComposer

    init(recommendationsComposer: RecommendationsComposer, logger: LoggerProtocol? = nil) {
        self.recommendationsComposer = recommendationsComposer
        self.logger = logger
    }

    private func updateView() {
        guard let all = allValidators, let recommended = recommended else {
            return
        }

        let totalCount = min(all.count, StakingConstants.maxTargets)
        let viewModel = SelectValidatorsStartViewModel(
            selectedCount: recommended.count,
            totalCount: totalCount
        )

        view?.didReceive(viewModel: viewModel)
    }

    private func prepareSelectedValidators(
        from electedValidatorList: [ElectedValidatorInfo]
    ) -> [SelectedValidatorInfo] {
        electedValidatorList.map {
            SelectedValidatorInfo(
                address: $0.address,
                identity: $0.identity,
                stakeInfo: ValidatorStakeInfo(
                    nominators: $0.nominators,
                    totalStake: $0.totalStake,
                    stakeReturn: $0.stakeReturn,
                    maxNominatorsRewarded: $0.maxNominatorsRewarded
                ),
                commission: $0.comission,
                blocked: $0.blocked
            )
        }
    }
}

extension SelectValidatorsStartPresenter: SelectValidatorsStartPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func selectRecommendedValidators() {
        guard let all = allValidators, let recommended = recommended else {
            return
        }

        let maxTargets = min(all.count, StakingConstants.maxTargets)
        let recommendedValidatorList = prepareSelectedValidators(from: recommended)

        wireframe.proceedToRecommendedList(
            from: view,
            validatorList: recommendedValidatorList,
            maxTargets: maxTargets
        )
    }

    func selectCustomValidators() {
        guard let all = allValidators else {
            return
        }

        let maxTargets = min(all.count, StakingConstants.maxTargets)
        let electedValidatorList = prepareSelectedValidators(from: all)
        let recommendedValidatorList = prepareSelectedValidators(from: recommended ?? [])

        wireframe.proceedToCustomList(
            from: view,
            validatorList: electedValidatorList,
            recommendedValidatorList: recommendedValidatorList,
            maxTargets: maxTargets
        )
    }
}

extension SelectValidatorsStartPresenter: SelectValidatorsStartInteractorOutputProtocol {
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
