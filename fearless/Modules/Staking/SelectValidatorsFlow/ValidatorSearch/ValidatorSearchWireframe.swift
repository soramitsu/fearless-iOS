final class ValidatorSearchWireframe: ValidatorSearchWireframeProtocol {
    func present(
        _ validatorInfo: ValidatorInfoProtocol,
        asset: AssetModel,
        chain: ChainModel,
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel
    ) {
        guard
            let validatorInfoView = ValidatorInfoViewFactory.createView(
                asset: asset,
                chain: chain,
                validatorInfo: validatorInfo,
                wallet: wallet
            ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            validatorInfoView.controller,
            animated: true
        )
    }

    func close(_ view: ControllerBackedProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }
}
