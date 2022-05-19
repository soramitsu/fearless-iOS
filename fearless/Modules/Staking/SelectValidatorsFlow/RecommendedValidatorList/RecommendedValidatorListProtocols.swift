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
        flow: ValidatorInfoFlow,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
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
        flow: RecommendedValidatorListFlow,
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        with state: InitiatedBonding
    ) -> RecommendedValidatorListViewProtocol?

    static func createChangeTargetsView(
        flow: RecommendedValidatorListFlow,
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        with state: ExistingBonding
    ) -> RecommendedValidatorListViewProtocol?

    static func createChangeYourValidatorsView(
        flow: RecommendedValidatorListFlow,
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        with state: ExistingBonding
    ) -> RecommendedValidatorListViewProtocol?
}
