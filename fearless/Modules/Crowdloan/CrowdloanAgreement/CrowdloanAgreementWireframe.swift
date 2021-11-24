import Foundation

final class CrowdloanAgreementWireframe: CrowdloanAgreementWireframeProtocol {
    let state: CrowdloanSharedState

    init(state: CrowdloanSharedState) {
        self.state = state
    }

    func showAgreementConfirm(
        from view: CrowdloanAgreementViewProtocol?,
        paraId: ParaId,
        customFlow: CustomCrowdloanFlow,
        remark: String
    ) {
        switch customFlow {
        case .moonbeam:
            guard let confirmationView = CrowdloanAgreementConfirmViewFactory.createView(
                paraId: paraId,
                customFlow: customFlow,
                remark: remark
            ) else {
                return
            }

            view?.controller.navigationController?.pushViewController(confirmationView.controller, animated: true)
        default: break
        }
    }

    func presentContributionSetup(
        from view: CrowdloanAgreementViewProtocol?,
        customFlow: CustomCrowdloanFlow,
        paraId: ParaId
    ) {
        guard let setupView = CrowdloanContributionSetupViewFactory.createView(
            for: paraId,
            state: state,
            customFlow: customFlow
        ) else {
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

        let viewModel = AlertPresentableViewModel(
            title: R.string.localizable.commonErrorGeneralTitle(preferredLanguages: locale?.rLanguages),
            message: message,
            actions: [proceedAction],
            closeAction: nil
        )

        present(viewModel: viewModel, style: .alert, from: view)
    }
}
