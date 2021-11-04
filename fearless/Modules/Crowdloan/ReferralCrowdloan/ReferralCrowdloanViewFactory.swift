import Foundation
import SoraKeystore
import SoraFoundation

struct ReferralCrowdloanViewFactory {
    static func createAstarView(
        for delegate: CustomCrowdloanDelegate,
        displayInfo: CrowdloanDisplayInfo,
        inputAmount: Decimal,
        existingService: CrowdloanBonusServiceProtocol?
    ) -> ReferralCrowdloanViewProtocol? {
        guard let paraId = ParaId(displayInfo.paraid) else {
            return nil
        }

        let bonusService: CrowdloanBonusServiceProtocol = {
            if let service = existingService as? AstarBonusService {
                return service
            } else {
                return AstarBonusService(
                    paraId: paraId,
                    operationManager: OperationManagerFacade.sharedManager
                )
            }
        }()

        let presenter = createAstarPresenter(
            for: delegate,
            displayInfo: displayInfo,
            inputAmount: inputAmount,
            bonusService: bonusService,
            defaultReferralCode: AstarBonusService.defaultReferralCode
        )

        return createView(presenter: presenter)
    }

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

        let presenter = createDefaultPresenter(
            for: delegate,
            displayInfo: displayInfo,
            inputAmount: inputAmount,
            bonusService: bonusService,
            defaultReferralCode: KaruraBonusService.defaultReferralCode
        )

        return createView(presenter: presenter)
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
                return BifrostBonusService(
                    paraId: paraId,
                    operationManager: OperationManagerFacade.sharedManager
                )
            }
        }()

        let presenter = createDefaultPresenter(
            for: delegate,
            displayInfo: displayInfo,
            inputAmount: inputAmount,
            bonusService: bonusService,
            defaultReferralCode: BifrostBonusService.defaultReferralCode
        )

        return createView(presenter: presenter)
    }

    private static func createView(
        presenter: ReferralCrowdloanPresenterProtocol
    ) -> ReferralCrowdloanViewProtocol? {
        let localizationManager = LocalizationManager.shared

        let view = ReferralCrowdloanViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view

        return view
    }

    private static func createPresenter<T: ReferralCrowdloanPresenterProtocol>(
        for delegate: CustomCrowdloanDelegate,
        displayInfo: CrowdloanDisplayInfo,
        inputAmount: Decimal,
        bonusService: CrowdloanBonusServiceProtocol,
        defaultReferralCode: String
    ) -> T {
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

        let localizationManager = LocalizationManager.shared

        return T(
            wireframe: wireframe,
            bonusService: bonusService,
            displayInfo: displayInfo,
            inputAmount: inputAmount,
            crowdloanDelegate: delegate,
            crowdloanViewModelFactory: viewModelFactory,
            defaultReferralCode: defaultReferralCode,
            localizationManager: localizationManager
        )
    }

    private static func createAstarPresenter(
        for delegate: CustomCrowdloanDelegate,
        displayInfo: CrowdloanDisplayInfo,
        inputAmount: Decimal,
        bonusService: CrowdloanBonusServiceProtocol,
        defaultReferralCode: String
    ) -> AstarReferralCrowdloanPresenter {
        createPresenter(
            for: delegate,
            displayInfo: displayInfo,
            inputAmount: inputAmount,
            bonusService: bonusService,
            defaultReferralCode: defaultReferralCode
        )
    }

    private static func createDefaultPresenter(
        for delegate: CustomCrowdloanDelegate,
        displayInfo: CrowdloanDisplayInfo,
        inputAmount: Decimal,
        bonusService: CrowdloanBonusServiceProtocol,
        defaultReferralCode: String
    ) -> ReferralCrowdloanPresenter {
        createPresenter(
            for: delegate,
            displayInfo: displayInfo,
            inputAmount: inputAmount,
            bonusService: bonusService,
            defaultReferralCode: defaultReferralCode
        )
    }
}
