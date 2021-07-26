import Foundation
import RobinHood

final class SelectValidatorsStartPresenter {
    weak var view: SelectValidatorsStartViewProtocol?
    var wireframe: SelectValidatorsStartWireframeProtocol!
    var interactor: SelectValidatorsStartInteractorInputProtocol!

    let logger: LoggerProtocol?

    private var allValidators: [ElectedValidatorInfo]?
    private var recommended: [ElectedValidatorInfo]?
    private var selectedValidators: SharedList<SelectedValidatorInfo> = .init(items: [])
    private var maxNominations: Int?

    init(logger: LoggerProtocol? = nil) {
        self.logger = logger
    }

    private func updateRecommendedValidators() {
        guard
            let all = allValidators,
            let maxNominations = maxNominations else {
            return
        }

        let resultLimit = min(all.count, maxNominations)
        let recomendedValidators = RecommendationsComposer(
            resultSize: resultLimit,
            clusterSizeLimit: StakingConstants.targetsClusterLimit
        ).compose(from: all)

        recommended = recomendedValidators
    }

    private func updateView() {
        guard
            let all = allValidators,
            let maxNominations = maxNominations else {
            return
        }

        let totalCount = min(all.count, maxNominations)
        let viewModel = SelectValidatorsStartViewModel(
            selectedCount: selectedValidators.count,
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

    private func handle(error: Error) {
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

extension SelectValidatorsStartPresenter: SelectValidatorsStartPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func updateOnAppearance() {
        updateView()
    }

    func selectRecommendedValidators() {
        guard
            let all = allValidators,
            let recommended = recommended,
            let maxNominations = maxNominations else {
            return
        }

        let maxTargets = min(all.count, maxNominations)
        let recommendedValidatorList = prepareSelectedValidators(from: recommended)

        wireframe.proceedToRecommendedList(
            from: view,
            validatorList: recommendedValidatorList,
            maxTargets: maxTargets
        )
    }

    func selectCustomValidators() {
        guard
            let all = allValidators,
            let maxNominations = maxNominations else {
            return
        }

        let maxTargets = min(all.count, maxNominations)
        let electedValidatorList = prepareSelectedValidators(from: all)
        let recommendedValidatorList = prepareSelectedValidators(from: recommended ?? [])

        wireframe.proceedToCustomList(
            from: view,
            validatorList: electedValidatorList,
            recommendedValidatorList: recommendedValidatorList,
            selectedValidatorList: selectedValidators,
            maxTargets: maxTargets
        )
    }
}

extension SelectValidatorsStartPresenter: SelectValidatorsStartInteractorOutputProtocol {
    func didReceiveValidators(result: Result<[ElectedValidatorInfo], Error>) {
        switch result {
        case let .success(validators):
            allValidators = validators

            updateRecommendedValidators()
            updateView()
        case let .failure(error):
            handle(error: error)
        }
    }

    func didReceiveMaxNominations(result: Result<Int, Error>) {
        switch result {
        case let .success(maxNominations):
            self.maxNominations = maxNominations

            updateRecommendedValidators()
            updateView()
        case let .failure(error):
            handle(error: error)
        }
    }
}
