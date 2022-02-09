import Foundation
import SoraFoundation

protocol SelectValidatorsStartViewProtocol: ControllerBackedProtocol, Localizable {
    func didReceive(viewModel: SelectValidatorsStartViewModel)
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
        from: ControllerBackedProtocol?,
        validatorList: [SelectedValidatorInfo],
        recommendedValidatorList: [SelectedValidatorInfo],
        selectedValidatorList: SharedList<SelectedValidatorInfo>,
        maxTargets: Int,
        asset: AssetModel,
        chain: ChainModel,
        selectedAccount: MetaAccountModel
    )

    func proceedToRecommendedList(
        from view: SelectValidatorsStartViewProtocol?,
        validatorList: [SelectedValidatorInfo],
        maxTargets: Int,
        selectedAccount: MetaAccountModel,
        chain: ChainModel,
        asset: AssetModel
    )
}

protocol SelectValidatorsStartViewFactoryProtocol: AnyObject {
    static func createInitiatedBondingView(
        selectedAccount: MetaAccountModel,
        asset: AssetModel,
        chain: ChainModel,
        state: InitiatedBonding
    )
        -> SelectValidatorsStartViewProtocol?

    static func createChangeTargetsView(
        selectedAccount: MetaAccountModel,
        asset: AssetModel,
        chain: ChainModel,
        state: ExistingBonding
    )
        -> SelectValidatorsStartViewProtocol?

    static func createChangeYourValidatorsView(
        selectedAccount: MetaAccountModel,
        asset: AssetModel,
        chain: ChainModel,
        state: ExistingBonding
    )
        -> SelectValidatorsStartViewProtocol?
}
