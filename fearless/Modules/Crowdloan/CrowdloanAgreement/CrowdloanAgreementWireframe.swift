import Foundation

final class CrowdloanAgreementWireframe: CrowdloanAgreementWireframeProtocol {
    func showMoonbeamAgreementConfirm(
        from view: CrowdloanAgreementViewProtocol?,
        paraId: ParaId,
        moonbeamFlowData: MoonbeamFlowData
    ) {
        guard let confirmationView = CrowdloanAgreementConfirmViewFactory.createMoonbeamView(
            paraId: paraId,
            moonbeamFlowData: moonbeamFlowData
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(confirmationView.controller, animated: true)
    }

    func presentContributionSetup(
        from view: CrowdloanAgreementViewProtocol?,
        paraId: ParaId
    ) {
        guard let setupView = CrowdloanContributionSetupViewFactory.createView(for: paraId) else {
            return
        }

        setupView.controller.hidesBottomBarWhenPushed = true

        guard var viewControllers = view?.controller.navigationController?.viewControllers else { return }

        _ = viewControllers.popLast()
        viewControllers.append(setupView.controller)

        view?.controller.navigationController?.setViewControllers(viewControllers, animated: false)
    }

    func presentUnavailableWarning(
        message: String?,
        view: ControllerBackedProtocol,
        locale: Locale?
    ) {
        let proceedTitle = R.string.localizable
            .commonOk(preferredLanguages: locale?.rLanguages)
        let proceedAction = AlertPresentableAction(title: proceedTitle) {
            view.controller.navigationController?.popViewController(animated: true)
        }

        let closeTitle = R.string.localizable
            .commonCancel(preferredLanguages: locale?.rLanguages)

        let viewModel = AlertPresentableViewModel(
            title: R.string.localizable.commonErrorGeneralTitle(preferredLanguages: locale?.rLanguages),
            message: message,
            actions: [proceedAction],
            closeAction: nil
        )

        present(
            viewModel: viewModel,
            style: .alert,
            from: view
        )
    }
}
