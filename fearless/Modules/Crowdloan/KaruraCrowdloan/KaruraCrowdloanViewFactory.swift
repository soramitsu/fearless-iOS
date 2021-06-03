import Foundation
import SoraKeystore

struct KaruraCrowdloanViewFactory {
    static func createView(
        for delegate: CustomCrowdloanDelegate,
        displayInfo: CrowdloanDisplayInfo,
        inputAmount: Decimal,
        existingService: CrowdloanBonusServiceProtocol?
    ) -> KaruraCrowdloanViewProtocol? {
        let settings = SettingsManager.shared

        guard let selectedAddress = settings.selectedAccount?.address else {
            return nil
        }

        let wireframe = KaruraCrowdloanWireframe()

        let signingWrapper = SigningWrapper(keystore: Keychain(), settings: settings)

        let bonusService: CrowdloanBonusServiceProtocol = {
            if let service = existingService {
                return service
            } else {
                return KaruraBonusService(
                    address: selectedAddress,
                    chain: settings.selectedConnection.type.chain,
                    signingWrapper: signingWrapper,
                    operationManager: OperationManagerFacade.sharedManager
                )
            }
        }()

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
