import Foundation
import SoraFoundation

protocol SelectValidatorsStartViewProtocol: ControllerBackedProtocol, Localizable {
    func didReceive(viewModel: SelectValidatorsStartViewModelProtocol)
}

protocol SelectValidatorsStartPresenterProtocol: AnyObject {
    func setup()
    func updateOnAppearance()

    func selectRecommendedValidators()
    func selectCustomValidators()
}

protocol SelectValidatorsStartInteractorInputProtocol: AnyObject {
    func setup()
}

protocol SelectValidatorsStartInteractorOutputProtocol: AnyObject {
    func didReceiveValidators(result: Result<[ElectedValidatorInfo], Error>)
    func didReceiveMaxNominations(result: Result<Int, Error>)
}

protocol SelectValidatorsStartWireframeProtocol: AlertPresentable, ErrorPresentable {
    func proceedToCustomList(
        from view: ControllerBackedProtocol?,
        validatorList: [SelectedValidatorInfo],
        recommendedValidatorList: [SelectedValidatorInfo],
        selectedValidatorList: SharedList<SelectedValidatorInfo>,
        maxTargets: Int
    )

    func proceedToRecommendedList(
        from view: SelectValidatorsStartViewProtocol?,
        validatorList: [SelectedValidatorInfo],
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
