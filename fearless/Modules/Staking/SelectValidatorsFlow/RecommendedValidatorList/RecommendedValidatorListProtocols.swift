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
    static func createView(
        flow: RecommendedValidatorListFlow,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) -> RecommendedValidatorListViewProtocol?
}
