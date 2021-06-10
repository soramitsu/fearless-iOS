import Foundation

final class SelectValidatorsPresenter {
    weak var view: SelectValidatorsViewProtocol?
    let wireframe: SelectValidatorsWireframeProtocol
    let interactor: SelectValidatorsInteractorInputProtocol
    let viewModelFactory: SelectValidatorsViewModelFactory
    private let selectedValidators: [ElectedValidatorInfo]
    private var viewModel: [SelectValidatorsCellViewModel] = []

    init(
        interactor: SelectValidatorsInteractorInputProtocol,
        wireframe: SelectValidatorsWireframeProtocol,
        viewModelFactory: SelectValidatorsViewModelFactory,
        validators: [ElectedValidatorInfo]
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        selectedValidators = validators
    }
}

extension SelectValidatorsPresenter: SelectValidatorsPresenterProtocol {
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
        wireframe.showValidatorInfo(from: view, validatorInfo: selectedValidator)
    }
}

extension SelectValidatorsPresenter: SelectValidatorsInteractorOutputProtocol {}
