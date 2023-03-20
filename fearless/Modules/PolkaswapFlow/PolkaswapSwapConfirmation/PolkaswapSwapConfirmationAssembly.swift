import UIKit
import SoraFoundation
import SoraKeystore

final class PolkaswapSwapConfirmationAssembly {
    static func configureModule(
        params: PolkaswapPreviewParams
    ) -> PolkaswapSwapConfirmationModuleCreationResult? {
        let localizationManager = LocalizationManager.shared
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let request = params.soraChinAsset.chain.accountRequest()

        guard let accountResponse = params.wallet.fetch(for: request),
              let runtimeService = chainRegistry.getRuntimeProvider(for: params.soraChinAsset.chain.chainId),
              let connection = chainRegistry.getConnection(for: params.soraChinAsset.chain.chainId)
        else {
            return nil
        }

        let signingWrapper = SigningWrapper(
            keystore: Keychain(),
            metaId: params.wallet.metaId,
            accountResponse: accountResponse
        )

        let operationManager = OperationManagerFacade.sharedManager
        let extrinsicService = ExtrinsicService(
            accountId: accountResponse.accountId,
            chainFormat: params.soraChinAsset.chain.chainFormat,
            cryptoType: accountResponse.cryptoType,
            runtimeRegistry: runtimeService,
            engine: connection,
            operationManager: operationManager
        )

        let callFactory = SubstrateCallFactory(runtimeSpecVersion: runtimeService.runtimeSpecVersion)

        let interactor = PolkaswapSwapConfirmationInteractor(
            params: params,
            signingWrapper: signingWrapper,
            extrinsicService: extrinsicService,
            callFactory: callFactory
        )
        let router = PolkaswapSwapConfirmationRouter()

        let presenter = PolkaswapSwapConfirmationPresenter(
            params: params,
            viewModelFactory: PolkaswapSwapConfirmationViewModelFactory(),
            interactor: interactor,
            router: router,
            localizationManager: localizationManager
        )

        let view = PolkaswapSwapConfirmationViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
