import Foundation
import RobinHood

final class RecommendedValidatorsPresenter {
    weak var view: RecommendedValidatorsViewProtocol?
    var wireframe: RecommendedValidatorsWireframeProtocol!
    var interactor: RecommendedValidatorsInteractorInputProtocol!

    let state: StartStakingResult
    let logger: LoggerProtocol?

    var allValidators: [ElectedValidatorInfo]?
    var recommended: [ElectedValidatorInfo]?

    init(state: StartStakingResult,
         logger: LoggerProtocol? = nil) {
        self.state = state
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
        guard let recommended = recommended else {
            return
        }

        let targets = recommended.map {
            SelectedValidatorInfo(address: $0.address,
                                  identity: $0.identity,
                                  stakeReturn: $0.stakeReturn)
        }

        let nomination = PreparedNomination(amount: state.amount,
                                            rewardDestination: state.rewardDestination,
                                            targets: targets)

        wireframe.proceed(from: view, result: nomination)
    }

    func selectRecommendedValidators() {
        guard let recommended = recommended else {
            return
        }

        wireframe.showRecommended(from: view, validators: recommended)
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

        let recommended = validators
            .filter { $0.hasIdentity && !$0.hasSlashes && !$0.oversubscribed}
            .sorted(by: { $0.stakeReturn >= $1.stakeReturn })
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
