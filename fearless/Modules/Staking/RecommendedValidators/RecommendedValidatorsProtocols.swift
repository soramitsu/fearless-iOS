import Foundation
import SoraFoundation

protocol RecommendedValidatorsViewProtocol: ControllerBackedProtocol, Localizable {
    func didReceive(viewModel: RecommendedViewModelProtocol)
}

protocol RecommendedValidatorsPresenterProtocol: AnyObject {
    func setup()

    func proceed()
    func selectRecommendedValidators()
    func selectCustomValidators()
}

protocol RecommendedValidatorsInteractorInputProtocol: AnyObject {
    func setup()
}

protocol RecommendedValidatorsInteractorOutputProtocol: AnyObject {
    func didReceive(validators: [ElectedValidatorInfo])
    func didReceive(error: Error)
}

protocol RecommendedValidatorsWireframeProtocol: AlertPresentable, ErrorPresentable {
    func proceed(
        from view: RecommendedValidatorsViewProtocol?,
        targets: [SelectedValidatorInfo],
        maxTargets: Int
    )

    func showRecommended(
        from view: RecommendedValidatorsViewProtocol?,
        validators: [ElectedValidatorInfo],
        maxTargets: Int
    )

    func showCustom(from view: RecommendedValidatorsViewProtocol?, validators: [ElectedValidatorInfo])
}

protocol RecommendedValidatorsViewFactoryProtocol: AnyObject {
    static func createInitiatedBondingView(with state: InitiatedBonding)
        -> RecommendedValidatorsViewProtocol?

    static func createChangeTargetsView(with state: ExistingBonding)
        -> RecommendedValidatorsViewProtocol?

    static func createChangeYourValidatorsView(with state: ExistingBonding)
        -> RecommendedValidatorsViewProtocol?
}
