import FearlessUtils
import RobinHood

struct SendDependencies {
    let wallet: MetaAccountModel
    let chainAsset: ChainAsset

    let runtimeService: RuntimeCodingServiceProtocol
    let extrinsicService: ExtrinsicServiceProtocol
    let existentialDepositService: ExistentialDepositServiceProtocol
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let equilibruimTotalBalanceService: EquilibriumTotalBalanceServiceProtocol?
    let callFactory: SubstrateCallFactoryProtocol
}

final class SendDepencyContainer {
    private let wallet: MetaAccountModel
    private let operationManager: OperationManagerProtocol
    private var currentChainAsset: ChainAsset?
    private var currentDependecies: SendDependencies?

    init(wallet: MetaAccountModel, operationManager: OperationManagerProtocol) {
        self.wallet = wallet
        self.operationManager = operationManager
    }

    func prepareDepencies(
        chainAsset: ChainAsset
    ) -> SendDependencies? {
        if chainAsset != currentChainAsset {
            let chainRegistry = ChainRegistryFacade.sharedRegistry
            guard
                let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
                let runtimeService = chainRegistry.getRuntimeProvider(
                    for: chainAsset.chain.chainId
                )
            else {
                return nil
            }

            guard let accountResponse = wallet.fetch(
                for: chainAsset.chain.accountRequest()
            )
            else {
                return nil
            }

            let extrinsicService = ExtrinsicService(
                accountId: accountResponse.accountId,
                chainFormat: chainAsset.chain.chainFormat,
                cryptoType: accountResponse.cryptoType,
                runtimeRegistry: runtimeService,
                engine: connection,
                operationManager: operationManager
            )

            let existentialDepositService = ExistentialDepositService(
                operationManager: operationManager,
                chainRegistry: chainRegistry,
                chainId: chainAsset.chain.chainId
            )

            let assetInfo = chainAsset.asset.displayInfo(with: chainAsset.chain.icon)
            let balanceViewModelFactory = BalanceViewModelFactory(
                targetAssetInfo: assetInfo,
                selectedMetaAccount: wallet
            )

            let equilibruimTotalBalanceService = createEqTotalBalanceService(chainAsset: chainAsset)

            let callFactory = SubstrateCallFactoryAssembly.createCallFactory(for: runtimeService.runtimeSpecVersion)

            currentDependecies = SendDependencies(
                wallet: wallet,
                chainAsset: chainAsset,
                runtimeService: runtimeService,
                extrinsicService: extrinsicService,
                existentialDepositService: existentialDepositService,
                balanceViewModelFactory: balanceViewModelFactory,
                equilibruimTotalBalanceService: equilibruimTotalBalanceService,
                callFactory: callFactory
            )
        }
        return currentDependecies
    }

    private func createEqTotalBalanceService(chainAsset: ChainAsset) -> EquilibriumTotalBalanceServiceProtocol? {
        guard chainAsset.chain.isEquilibrium else {
            return nil
        }
        if let equilibruimTotalBalanceService = currentDependecies?.equilibruimTotalBalanceService {
            return equilibruimTotalBalanceService
        }
        return EquilibriumTotalBalanceServiceFactory
            .createService(wallet: wallet, chainAsset: chainAsset)
    }
}
