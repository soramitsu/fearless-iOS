import Foundation
import SoraFoundation

protocol RecommendedValidatorsViewProtocol: ControllerBackedProtocol, Localizable {
    func didReceive(viewModel: RecommendedViewModelProtocol)
}

protocol RecommendedValidatorsPresenterProtocol: class {
    func setup()

    func proceed()
    func selectRecommendedValidators()
    func selectCustomValidators()
}

protocol RecommendedValidatorsInteractorInputProtocol: class {
    func setup()
}

protocol RecommendedValidatorsInteractorOutputProtocol: class {
    func didReceive(validators: [ElectedValidatorInfo])
    func didReceive(error: Error)
}

protocol RecommendedValidatorsWireframeProtocol: AlertPresentable, ErrorPresentable {}

protocol RecommendedValidatorsViewFactoryProtocol: class {
    static func createView(with stakingState: StartStakingResult) -> RecommendedValidatorsViewProtocol?
}
