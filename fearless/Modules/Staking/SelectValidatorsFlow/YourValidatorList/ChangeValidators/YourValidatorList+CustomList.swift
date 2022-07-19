extension YourValidatorList {
    final class CustomListWireframe: CustomValidatorListWireframe {
        override func proceed(
            from view: ControllerBackedProtocol?,
            flow: SelectedValidatorListFlow,
            delegate: SelectedValidatorListDelegate,
            chainAsset: ChainAsset,
            wallet: MetaAccountModel
        ) {
            guard let nextView = SelectedValidatorListViewFactory.createView(
                flow: flow,
                chainAsset: chainAsset,
                wallet: wallet,
                delegate: delegate
            )
            else { return }

            view?.controller.navigationController?.pushViewController(
                nextView.controller,
                animated: true
            )
        }
    }
}
