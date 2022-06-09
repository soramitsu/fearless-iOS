import SoraFoundation

protocol RecommendedValidatorListViewProtocol: ControllerBackedProtocol, Localizable {
    func didReceive(viewModel: RecommendedValidatorListViewModelProtocol)
}

protocol RecommendedValidatorListPresenterProtocol: AnyObject {
    func setup()
    func selectedValidatorAt(index: Int)
    func showValidatorInfoAt(index: Int)
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
        from _: RecommendedValidatorListViewProtocol?,
        flow _: SelectValidatorsConfirmFlow,
        wallet _: MetaAccountModel,
        chainAsset _: ChainAsset
    )
}

protocol RecommendedValidatorListViewFactoryProtocol: AnyObject {
    static func createInitiatedBondingView(
        flow: RecommendedValidatorListFlow,
        wallet: MetaAccountModel,
        chainAsset: ChainAsset
    ) -> RecommendedValidatorListViewProtocol?

    static func createChangeTargetsView(
        flow: RecommendedValidatorListFlow,
        wallet: MetaAccountModel,
        chainAsset: ChainAsset
    ) -> RecommendedValidatorListViewProtocol?

    static func createChangeYourValidatorsView(
        flow: RecommendedValidatorListFlow,
        wallet: MetaAccountModel,
        chainAsset: ChainAsset
    ) -> RecommendedValidatorListViewProtocol?
}
