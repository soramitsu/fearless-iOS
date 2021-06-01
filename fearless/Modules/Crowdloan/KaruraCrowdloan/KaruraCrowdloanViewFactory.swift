import Foundation

struct KaruraCrowdloanViewFactory {
    static func createView(
        for delegate: CustomCrowdloanDelegate,
        displayInfo: CrowdloanDisplayInfo,
        inputAmount: Decimal
    ) -> KaruraCrowdloanViewProtocol? {
        let wireframe = KaruraCrowdloanWireframe()

        let bonusService = KaruraBonusService()

        let presenter = KaruraCrowdloanPresenter(
            wireframe: wireframe,
            bonusService: bonusService,
            displayInfo: displayInfo,
            inputAmount: inputAmount,
            crowdloanDelegate: delegate
        )

        let view = KaruraCrowdloanViewController(presenter: presenter)

        presenter.view = view

        return view
    }
}
