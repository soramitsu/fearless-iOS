import Foundation

protocol AccountScorePresentable {
    func presentAccountScore(
        address: String?,
        from view: ControllerBackedProtocol?
    )
}

extension AccountScorePresentable {
    func presentAccountScore(
        address: String?,
        from view: ControllerBackedProtocol?
    ) {
        guard let controller = view?.controller else {
            return
        }

        let accountScoreViewController = AccountStatisticsAssembly.configureModule(address: address)?.view.controller

        guard let accountScoreViewController else {
            return
        }

        controller.present(accountScoreViewController, animated: true)
    }
}
