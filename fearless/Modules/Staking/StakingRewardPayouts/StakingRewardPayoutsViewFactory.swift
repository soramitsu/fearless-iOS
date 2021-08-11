import Foundation
import SoraKeystore
import SoraFoundation
import FearlessUtils
import IrohaCrypto

final class StakingRewardPayoutsViewFactory: StakingRewardPayoutsViewFactoryProtocol {
    static func createViewForNominator(
        stashAddress: AccountAddress
    ) -> StakingRewardPayoutsViewProtocol? {
        let settings = SettingsManager.shared
        let connection = settings.selectedConnection
        let operationManager = OperationManagerFacade.sharedManager

        let chain = connection.type.chain

        let primitiveFactory = WalletPrimitiveFactory(settings: settings)

        let asset = primitiveFactory.createAssetForAddressType(chain.addressType)

        guard let assetId = WalletAssetId(rawValue: asset.identifier),
              let subscanUrl = assetId.subscanUrl else {
            return nil
        }

        let validatorsResolutionFactory = PayoutValidatorsForNominatorFactory(
            chain: chain,
            subqueryURL: URL(string: "http://localhost:3000/")! // TODO: delete stub url
        )

        let payoutInfoFactory = NominatorPayoutInfoFactory(
            addressType: chain.addressType,
            addressFactory: SS58AddressFactory()
        )

        return createView(
            for: stashAddress,
            validatorsResolutionFactory: validatorsResolutionFactory,
            payoutInfoFactory: payoutInfoFactory
        )
    }

    static func createViewForValidator(stashAddress: AccountAddress) -> StakingRewardPayoutsViewProtocol? {
        let connection = SettingsManager.shared.selectedConnection
        let chain = connection.type.chain

        let validatorsResolutionFactory = PayoutValidatorsForValidatorFactory()

        let payoutInfoFactory = ValidatorPayoutInfoFactory(
            addressType: chain.addressType,
            addressFactory: SS58AddressFactory()
        )

        return createView(
            for: stashAddress,
            validatorsResolutionFactory: validatorsResolutionFactory,
            payoutInfoFactory: payoutInfoFactory
        )
    }

    private static func createView(
        for stashAddress: AccountAddress,
        validatorsResolutionFactory: PayoutValidatorsFactoryProtocol,
        payoutInfoFactory: PayoutInfoFactoryProtocol
    ) -> StakingRewardPayoutsViewProtocol? {
        let settings = SettingsManager.shared
        let connection = settings.selectedConnection
        let operationManager = OperationManagerFacade.sharedManager
        let chain = connection.type.chain

        guard let engine = WebSocketService.shared.connection else { return nil }

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )

        let identityOperationFactory = IdentityOperationFactory(requestFactory: storageRequestFactory)

        let payoutService = PayoutRewardsService(
            selectedAccountAddress: stashAddress,
            chain: chain,
            validatorsResolutionFactory: validatorsResolutionFactory,
            runtimeCodingService: RuntimeRegistryFacade.sharedService,
            storageRequestFactory: storageRequestFactory,
            engine: engine,
            operationManager: operationManager,
            identityOperationFactory: identityOperationFactory,
            payoutInfoFactory: payoutInfoFactory,
            logger: Logger.shared
        )

        return createView(for: payoutService)
    }

    private static func createView(
        for payoutService: PayoutRewardsServiceProtocol
    ) -> StakingRewardPayoutsViewProtocol? {
        let settings = SettingsManager.shared
        let connection = settings.selectedConnection
        let operationManager = OperationManagerFacade.sharedManager

        let chain = connection.type.chain

        let primitiveFactory = WalletPrimitiveFactory(settings: settings)

        let asset = primitiveFactory.createAssetForAddressType(chain.addressType)

        guard let assetId = WalletAssetId(rawValue: asset.identifier) else {
            return nil
        }

        let balanceViewModelFactory = BalanceViewModelFactory(
            walletPrimitiveFactory: primitiveFactory,
            selectedAddressType: connection.type,
            limit: StakingConstants.maxAmount
        )
        let payoutsViewModelFactory = StakingPayoutViewModelFactory(
            chain: chain,
            balanceViewModelFactory: balanceViewModelFactory,
            timeFormatter: TotalTimeFormatter()
        )
        let presenter = StakingRewardPayoutsPresenter(
            chain: chain,
            viewModelFactory: payoutsViewModelFactory
        )
        let view = StakingRewardPayoutsViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared,
            countdownTimer: CountdownTimer()
        )

        let runtimeService = RuntimeRegistryFacade.sharedService
        let keyFactory = StorageKeyFactory()
        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: keyFactory,
            operationManager: operationManager
        )

        let eraCountdownOperationFactory = EraCountdownOperationFactory(
            runtimeCodingService: runtimeService,
            storageRequestFactory: storageRequestFactory,
            webSocketService: WebSocketService.shared
        )

        let interactor = StakingRewardPayoutsInteractor(
            singleValueProviderFactory: SingleValueProviderFactory.shared,
            payoutService: payoutService,
            assetId: assetId,
            chain: chain,
            eraCountdownOperationFactory: eraCountdownOperationFactory,
            operationManager: operationManager,
            runtimeService: runtimeService,
            logger: Logger.shared
        )
        let wireframe = StakingRewardPayoutsWireframe()

        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }
}
