import Foundation
import RobinHood

final class SelectValidatorsStartPresenter {
    weak var view: SelectValidatorsStartViewProtocol?
    let wireframe: SelectValidatorsStartWireframeProtocol
    let interactor: SelectValidatorsStartInteractorInputProtocol

    let initialTargets: [SelectedValidatorInfo]?
    let existingStashAddress: AccountAddress?
    let logger: LoggerProtocol?

    private var allValidators: [AccountAddress: ElectedValidatorInfo]?
    private var recommended: [ElectedValidatorInfo]?
    private var selectedValidators: SharedList<SelectedValidatorInfo>?
    private var maxNominations: Int?

    init(
        interactor: SelectValidatorsStartInteractorInputProtocol,
        wireframe: SelectValidatorsStartWireframeProtocol,
        existingStashAddress: AccountAddress?,
        initialTargets: [SelectedValidatorInfo]?,
        logger: LoggerProtocol? = nil
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.existingStashAddress = existingStashAddress
        self.initialTargets = initialTargets
        self.logger = logger
    }

    private func updateSelectedValidatorsIfNeeded() {
        guard
            let all = allValidators,
            let maxNominations = maxNominations,
            selectedValidators == nil else {
            return
        }

        let selectedValidatorList = initialTargets?.map { target in
            all[target.address]?.toSelected(for: existingStashAddress) ?? target
        }
        .sorted { $0.stakeReturn > $1.stakeReturn }
        .prefix(maxNominations) ?? []

        selectedValidators = SharedList(items: selectedValidatorList)
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
        ).compose(from: Array(all.values))

        recommended = recomendedValidators
    }

    private func updateView() {
        guard
            let maxNominations = maxNominations,
            let selectedValidators = selectedValidators else {
            return
        }

        let viewModel = SelectValidatorsStartViewModel(
            phase: initialTargets == nil ? .setup : .update,
            selectedCount: selectedValidators.count,
            totalCount: maxNominations
        )

        view?.didReceive(viewModel: viewModel)
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
        let recommendedValidatorList = recommended.map { $0.toSelected(for: existingStashAddress) }

        wireframe.proceedToRecommendedList(
            from: view,
            validatorList: recommendedValidatorList,
            maxTargets: maxTargets
        )
    }

    func selectCustomValidators() {
        guard
            let all = allValidators,
            let maxNominations = maxNominations,
            let selectedValidators = selectedValidators else {
            return
        }

        let maxTargets = min(all.count, maxNominations)
        let electedValidatorList = all.values.map { $0.toSelected(for: existingStashAddress) }
        let recommendedValidatorList = recommended?.map {
            $0.toSelected(for: existingStashAddress)
        } ?? []

        let notElectedValidators = selectedValidators.items.compactMap {
            all[$0.address] == nil ? $0 : nil
        }

        wireframe.proceedToCustomList(
            from: view,
            validatorList: electedValidatorList + notElectedValidators,
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
            allValidators = validators.reduce(
                into: [AccountAddress: ElectedValidatorInfo]()
            ) { dict, validator in
                dict[validator.address] = validator
            }

            updateRecommendedValidators()
            updateSelectedValidatorsIfNeeded()
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
            updateSelectedValidatorsIfNeeded()
            updateView()
        case let .failure(error):
            handle(error: error)
        }
    }
}
