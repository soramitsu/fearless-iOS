import Foundation
import SoraKeystore

struct ReferralCrowdloanViewFactory {
    static func createKaruraView(
        for delegate: CustomCrowdloanDelegate,
        displayInfo: CrowdloanDisplayInfo,
        inputAmount: Decimal,
        existingService: CrowdloanBonusServiceProtocol?
    ) -> ReferralCrowdloanViewProtocol? {
        let settings = SettingsManager.shared

        guard let selectedAddress = settings.selectedAccount?.address else {
            return nil
        }

        let bonusService: CrowdloanBonusServiceProtocol = {
            if let service = existingService as? KaruraBonusService {
                return service
            } else {
                return KaruraBonusService(
                    address: selectedAddress,
                    chain: settings.selectedConnection.type.chain,
                    signingWrapper: SigningWrapper(keystore: Keychain(), settings: settings),
                    operationManager: OperationManagerFacade.sharedManager
                )
            }
        }()

        return createView(
            for: delegate,
            displayInfo: displayInfo,
            inputAmount: inputAmount,
            bonusService: bonusService
        )
    }

    static func createBifrostView(
        for delegate: CustomCrowdloanDelegate,
        displayInfo: CrowdloanDisplayInfo,
        inputAmount: Decimal,
        existingService: CrowdloanBonusServiceProtocol?
    ) -> ReferralCrowdloanViewProtocol? {
        guard let paraId = ParaId(displayInfo.paraid) else {
            return nil
        }

        let bonusService: CrowdloanBonusServiceProtocol = {
            if let service = existingService as? BifrostBonusService {
                return service
            } else {
                return BifrostBonusService(paraId: paraId)
            }
        }()

        return createView(
            for: delegate,
            displayInfo: displayInfo,
            inputAmount: inputAmount,
            bonusService: bonusService
        )
    }

    private static func createView(
        for delegate: CustomCrowdloanDelegate,
        displayInfo: CrowdloanDisplayInfo,
        inputAmount: Decimal,
        bonusService: CrowdloanBonusServiceProtocol
    ) -> ReferralCrowdloanViewProtocol? {
        let settings = SettingsManager.shared

        let wireframe = ReferralCrowdloanWireframe()

        let addressType = settings.selectedConnection.type
        let primitiveFactory = WalletPrimitiveFactory(settings: settings)
        let asset = primitiveFactory.createAssetForAddressType(addressType)

        let viewModelFactory = CrowdloanContributionViewModelFactory(
            amountFormatterFactory: AmountFormatterFactory(),
            chainDateCalculator: ChainDateCalculator(),
            asset: asset
        )

        let presenter = ReferralCrowdloanPresenter(
            wireframe: wireframe,
            bonusService: bonusService,
            displayInfo: displayInfo,
            inputAmount: inputAmount,
            crowdloanDelegate: delegate,
            crowdloanViewModelFactory: viewModelFactory,
            defaultReferralCode: KaruraBonusService.defaultReferralCode
        )

        let view = ReferralCrowdloanViewController(presenter: presenter)

        presenter.view = view

        return view
    }
}
