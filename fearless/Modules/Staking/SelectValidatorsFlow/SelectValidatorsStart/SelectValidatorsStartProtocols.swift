import Foundation
import SoraFoundation

protocol SelectValidatorsStartViewProtocol: ControllerBackedProtocol, Localizable {
    func didReceive(viewModel: SelectValidatorsStartViewModelProtocol)
}

protocol SelectValidatorsStartPresenterProtocol: AnyObject {
    func setup()

    func selectRecommendedValidators()
    func selectCustomValidators()
}

protocol SelectValidatorsStartInteractorInputProtocol: AnyObject {
    func setup()
}

protocol SelectValidatorsStartInteractorOutputProtocol: AnyObject {
    func didReceive(validators: [ElectedValidatorInfo])
    func didReceive(error: Error)
}

protocol SelectValidatorsStartWireframeProtocol: AlertPresentable, ErrorPresentable {
    func proceedToCustomList(
        from view: ControllerBackedProtocol?,
        validators: [ElectedValidatorInfo],
        recommended: [ElectedValidatorInfo],
        maxTargets: Int
    )

    func proceedToRecommendedList(
        from view: SelectValidatorsStartViewProtocol?,
        validators: [ElectedValidatorInfo],
        maxTargets: Int
    )
}

protocol SelectValidatorsStartViewFactoryProtocol: AnyObject {
    static func createInitiatedBondingView(with state: InitiatedBonding)
        -> SelectValidatorsStartViewProtocol?

    static func createChangeTargetsView(with state: ExistingBonding)
        -> SelectValidatorsStartViewProtocol?

    static func createChangeYourValidatorsView(with state: ExistingBonding)
        -> SelectValidatorsStartViewProtocol?
}
