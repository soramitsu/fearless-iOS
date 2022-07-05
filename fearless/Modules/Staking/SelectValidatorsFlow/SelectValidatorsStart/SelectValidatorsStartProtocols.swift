import Foundation
import SoraFoundation

protocol SelectValidatorsStartViewProtocol: ControllerBackedProtocol, Localizable {
    func didReceive(viewModel: SelectValidatorsStartViewModel)
    func didReceive(textsViewModel: SelectValidatorsStartTextsViewModel)
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

protocol SelectValidatorsStartInteractorOutputProtocol: AnyObject {}

protocol SelectValidatorsStartWireframeProtocol: AlertPresentable, ErrorPresentable {
    func proceedToCustomList(
        from view: ControllerBackedProtocol?,
        flow: CustomValidatorListFlow,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    )

    func proceedToRecommendedList(
        from view: SelectValidatorsStartViewProtocol?,
        flow: RecommendedValidatorListFlow,
        wallet: MetaAccountModel,
        chainAsset: ChainAsset
    )
}

protocol SelectValidatorsStartViewFactoryProtocol: AnyObject {
    static func createInitiatedBondingView(
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        flow: SelectValidatorsStartFlow
    )
        -> SelectValidatorsStartViewProtocol?

    static func createChangeTargetsView(
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        flow: SelectValidatorsStartFlow
    )
        -> SelectValidatorsStartViewProtocol?

    static func createChangeYourValidatorsView(
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        flow: SelectValidatorsStartFlow
    )
        -> SelectValidatorsStartViewProtocol?
}
