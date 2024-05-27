import SSFUtils
import SSFModels
import SSFRuntimeCodingService

struct BalanceInfoDependencies {
    let connection: JSONRPCEngine?
    let runtimeService: RuntimeCodingServiceProtocol?
    let existentialDepositService: ExistentialDepositServiceProtocol
    let accountInfoFetching: AccountInfoFetchingProtocol
    let balanceLocksFetcher: BalanceLocksFetching?
}

final class BalanceInfoDepencyContainer {
    func prepareDepencies(
        chainAsset: ChainAsset
    ) -> BalanceInfoDependencies? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId)
        let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId)
        let operationManager = OperationManagerFacade.sharedManager
        let existentialDepositService = ExistentialDepositService(
            operationManager: operationManager,
            chainRegistry: chainRegistry,
            chainId: chainAsset.chain.chainId
        )
        let balanceLocksFetcher = BalanceLocksFetchingFactory.buildBalanceLocksFetcher(for: chainAsset)

        return BalanceInfoDependencies(
            connection: connection,
            runtimeService: runtimeService,
            existentialDepositService: existentialDepositService,
            accountInfoFetching: createAccountInfoFetching(for: chainAsset),
            balanceLocksFetcher: balanceLocksFetcher
        )
    }

    private func createAccountInfoFetching(for _: ChainAsset) -> AccountInfoFetchingProtocol {
        let substrateRepositoryFactory = SubstrateRepositoryFactory(
            storageFacade: UserDataStorageFacade.shared
        )

        let accountInfoRepository = substrateRepositoryFactory.createAccountInfoStorageItemRepository()

        let substrateAccountInfoFetching = AccountInfoFetching(
            accountInfoRepository: accountInfoRepository,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        return substrateAccountInfoFetching
    }
}
