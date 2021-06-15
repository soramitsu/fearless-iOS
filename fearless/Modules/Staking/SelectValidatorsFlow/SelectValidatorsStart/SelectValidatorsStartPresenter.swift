import Foundation
import RobinHood

final class SelectValidatorsStartPresenter {
    weak var view: SelectValidatorsStartViewProtocol?
    var wireframe: SelectValidatorsStartWireframeProtocol!
    var interactor: SelectValidatorsStartInteractorInputProtocol!

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
        let viewModel = SelectValidatorsStartViewModel(
            selectedCount: recommended.count,
            totalCount: totalCount
        )

        view?.didReceive(viewModel: viewModel)
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

        wireframe.proceedToRecommendedList(
            from: view,
            validators: recommended,
            maxTargets: maxTargets
        )
    }

    func selectCustomValidators() {
        guard let all = allValidators else {
            return
        }

        let maxTargets = min(all.count, StakingConstants.maxTargets)

        wireframe.proceedToCustomList(
            from: view,
            validators: all,
            recommended: recommended ?? [],
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
