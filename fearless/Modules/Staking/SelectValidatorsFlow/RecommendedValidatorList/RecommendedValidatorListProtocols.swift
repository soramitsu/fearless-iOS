import SoraFoundation

protocol RecommendedValidatorListViewProtocol: ControllerBackedProtocol, Localizable {
    func didReceive(viewModel: RecommendedValidatorListViewModelProtocol)
}

protocol RecommendedValidatorListPresenterProtocol: AnyObject {
    func setup()
    func selectedValidatorAt(index: Int)
    func proceed()
}

protocol RecommendedValidatorListWireframeProtocol: AnyObject {
    func present(
        asset: AssetModel,
        chain: ChainModel,
        validatorInfo: SelectedValidatorInfo,
        from view: RecommendedValidatorListViewProtocol?
    )

    func proceed(
        from view: RecommendedValidatorListViewProtocol?,
        targets: [SelectedValidatorInfo],
        maxTargets: Int,
        selectedAccount: MetaAccountModel,
        asset: AssetModel,
        chain: ChainModel
    )
}

protocol RecommendedValidatorListViewFactoryProtocol: AnyObject {
    static func createInitiatedBondingView(
        for validators: [SelectedValidatorInfo],
        maxTargets: Int,
        selectedAccount: MetaAccountModel,
        asset: AssetModel,
        chain: ChainModel,
        with state: InitiatedBonding
    ) -> RecommendedValidatorListViewProtocol?

    static func createChangeTargetsView(
        for validators: [SelectedValidatorInfo],
        maxTargets: Int,
        selectedAccount: MetaAccountModel,
        asset: AssetModel,
        chain: ChainModel,
        with state: ExistingBonding
    ) -> RecommendedValidatorListViewProtocol?

    static func createChangeYourValidatorsView(
        for validators: [SelectedValidatorInfo],
        maxTargets: Int,
        selectedAccount: MetaAccountModel,
        asset: AssetModel,
        chain: ChainModel,
        with state: ExistingBonding
    ) -> RecommendedValidatorListViewProtocol?
}
