import Foundation

final class CustomValidatorListPresenter {
    weak var view: CustomValidatorListViewProtocol?
    let wireframe: CustomValidatorListWireframeProtocol
    let interactor: CustomValidatorListInteractorInputProtocol
    let viewModelFactory: CustomValidatorListViewModelFactory
    private let selectedValidators: [ElectedValidatorInfo]
    private var viewModel: [CustomValidatorCellViewModel] = []

    init(
        interactor: CustomValidatorListInteractorInputProtocol,
        wireframe: CustomValidatorListWireframeProtocol,
        viewModelFactory: CustomValidatorListViewModelFactory,
        validators: [ElectedValidatorInfo]
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        selectedValidators = validators
    }
}

extension CustomValidatorListPresenter: CustomValidatorListPresenterProtocol {
    func setup() {
        let viewModel = viewModelFactory.createViewModel(validators: selectedValidators)
        view?.reload(with: viewModel)
    }

    func didSelectValidator(at index: Int) {
        let validator = selectedValidators[index]
        let selectedValidator = SelectedValidatorInfo(
            address: validator.address,
            identity: validator.identity,
            stakeInfo: ValidatorStakeInfo(
                nominators: validator.nominators,
                totalStake: validator.totalStake,
                stakeReturn: validator.stakeReturn,
                maxNominatorsRewarded: validator.maxNominatorsRewarded
            )
        )
        wireframe.present(selectedValidator, from: view)
    }
}

extension CustomValidatorListPresenter: CustomValidatorListInteractorOutputProtocol {}
