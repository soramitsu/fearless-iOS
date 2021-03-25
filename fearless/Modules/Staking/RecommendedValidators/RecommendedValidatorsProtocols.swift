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

protocol RecommendedValidatorsWireframeProtocol: AlertPresentable, ErrorPresentable {
    func proceed(from view: RecommendedValidatorsViewProtocol?,
                 targets: [SelectedValidatorInfo],
                 maxTargets: Int)

    func showRecommended(from view: RecommendedValidatorsViewProtocol?,
                         validators: [ElectedValidatorInfo],
                         maxTargets: Int)

    func showCustom(from view: RecommendedValidatorsViewProtocol?, validators: [ElectedValidatorInfo])
}

protocol RecommendedValidatorsViewFactoryProtocol: class {
    static func createInitiatedBondingView(with state: InitiatedBonding)
    -> RecommendedValidatorsViewProtocol?

    static func createChangeTargetsView(with state: ExistingBonding)
    -> RecommendedValidatorsViewProtocol?
}
