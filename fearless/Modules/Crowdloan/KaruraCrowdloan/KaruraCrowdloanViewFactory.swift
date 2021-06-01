import Foundation
import SoraKeystore

struct KaruraCrowdloanViewFactory {
    static func createView(
        for delegate: CustomCrowdloanDelegate,
        displayInfo: CrowdloanDisplayInfo,
        inputAmount: Decimal
    ) -> KaruraCrowdloanViewProtocol? {
        let wireframe = KaruraCrowdloanWireframe()

        let bonusService = KaruraBonusService()

        let settings = SettingsManager.shared
        let addressType = settings.selectedConnection.type
        let primitiveFactory = WalletPrimitiveFactory(settings: settings)
        let asset = primitiveFactory.createAssetForAddressType(addressType)

        let viewModelFactory = CrowdloanContributionViewModelFactory(
            amountFormatterFactory: AmountFormatterFactory(),
            chainDateCalculator: ChainDateCalculator(),
            asset: asset
        )

        let presenter = KaruraCrowdloanPresenter(
            wireframe: wireframe,
            bonusService: bonusService,
            displayInfo: displayInfo,
            inputAmount: inputAmount,
            crowdloanDelegate: delegate,
            crowdloanViewModelFactory: viewModelFactory,
            defaultReferralCode: KaruraBonusService.defaultReferralCode
        )

        let view = KaruraCrowdloanViewController(presenter: presenter)

        presenter.view = view

        return view
    }
}
