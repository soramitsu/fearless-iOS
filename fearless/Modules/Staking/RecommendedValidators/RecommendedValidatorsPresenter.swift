import Foundation
import RobinHood

final class RecommendedValidatorsPresenter {
    weak var view: RecommendedValidatorsViewProtocol?
    var wireframe: RecommendedValidatorsWireframeProtocol!
    var interactor: RecommendedValidatorsInteractorInputProtocol!

    let logger: LoggerProtocol?

    var allValidators: [ElectedValidatorInfo]?
    var recommended: [ElectedValidatorInfo]?

    init(logger: LoggerProtocol? = nil) {
        self.logger = logger
    }

    private func updateView() {
        guard let all = allValidators, let recommended = recommended else {
            return
        }

        let totalCount = min(all.count, StakingConstants.maxTargets)
        let viewModel = RecommendedViewModel(selectedCount: recommended.count,
                                             totalCount: totalCount)

        view?.didReceive(viewModel: viewModel)
    }
}

extension RecommendedValidatorsPresenter: RecommendedValidatorsPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func proceed() {

    }

    func selectRecommendedValidators() {

    }

    func selectCustomValidators() {
        
    }
}

extension RecommendedValidatorsPresenter: RecommendedValidatorsInteractorOutputProtocol {
    func didReceive(validators: [ElectedValidatorInfo]) {
        allValidators = validators

        let recommended = validators
            .filter { $0.hasIdentity && !$0.hasSlashes && !$0.oversubscribed}
            .sorted(by: { $0.stakeReturnPer >= $1.stakeReturnPer })
            .prefix(StakingConstants.maxTargets)
        self.recommended = Array(recommended)

        updateView()
    }

    func didReceive(error: Error) {
        logger?.error("Did receive error \(error)")

        let locale = view?.localizationManager?.selectedLocale
        if !wireframe.present(error: error, from: view, locale: locale) {
            _ = wireframe.present(error: BaseOperationError.unexpectedDependentResult,
                                  from: view,
                                  locale: locale)
        }
    }
}
