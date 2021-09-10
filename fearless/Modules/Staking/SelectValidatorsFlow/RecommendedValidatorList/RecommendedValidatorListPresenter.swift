import Foundation

final class RecommendedValidatorListPresenter {
    weak var view: RecommendedValidatorListViewProtocol?
    var wireframe: RecommendedValidatorListWireframeProtocol!

    let viewModelFactory: RecommendedValidatorListViewModelFactoryProtocol
    let validators: [SelectedValidatorInfo]
    let maxTargets: Int
    let logger: LoggerProtocol?

    init(
        viewModelFactory: RecommendedValidatorListViewModelFactoryProtocol,
        validators: [SelectedValidatorInfo],
        maxTargets: Int,
        logger: LoggerProtocol? = nil
    ) {
        self.viewModelFactory = viewModelFactory
        self.validators = validators
        self.maxTargets = maxTargets
        self.logger = logger
    }

    private func provideViewModel() {
        do {
            let viewModel = try viewModelFactory.createViewModel(
                from: validators,
                maxTargets: maxTargets
            )

            view?.didReceive(viewModel: viewModel)
        } catch {
            logger?.debug("Did receive error: \(error)")
        }
    }
}

extension RecommendedValidatorListPresenter: RecommendedValidatorListPresenterProtocol {
    func setup() {
        provideViewModel()
    }

    func selectedValidatorAt(index: Int) {
        let selectedValidator = validators[index]
        wireframe.present(
            selectedValidator,
            from: view
        )
    }

    func proceed() {
        wireframe.proceed(from: view, targets: validators, maxTargets: maxTargets)
    }
}
