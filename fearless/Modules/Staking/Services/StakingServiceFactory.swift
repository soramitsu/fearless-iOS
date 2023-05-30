import Foundation
import RobinHood
import SSFUtils
import SSFModels

enum StakingServiceFactoryError: Error {
    case stakingUnavailable
}

protocol StakingServiceFactoryProtocol {
    func createEraValidatorService(for chain: ChainModel) throws -> EraValidatorServiceProtocol
    func createRewardCalculatorService(
        for chainAsset: ChainAsset,
        assetPrecision: Int16,
        validatorService: EraValidatorServiceProtocol,
        collatorOperationFactory: ParachainCollatorOperationFactory?,
        wallet: MetaAccountModel
    ) throws -> RewardCalculatorServiceProtocol
}

final class StakingServiceFactory: StakingServiceFactoryProtocol {
    let chainRegisty: ChainRegistryProtocol
    let storageFacade: StorageFacadeProtocol
    let eventCenter: EventCenterProtocol
    let operationManager: OperationManagerProtocol
    let logger: LoggerProtocol?

    private lazy var substrateDataProviderFactory = SubstrateDataProviderFactory(
        facade: storageFacade,
        operationManager: operationManager
    )

    init(
        chainRegisty: ChainRegistryProtocol,
        storageFacade: StorageFacadeProtocol,
        eventCenter: EventCenterProtocol,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.chainRegisty = chainRegisty
        self.storageFacade = storageFacade
        self.eventCenter = eventCenter
        self.operationManager = operationManager
        self.logger = logger
    }

    func createEraValidatorService(for chain: ChainModel) throws -> EraValidatorServiceProtocol {
        guard let runtimeService = chainRegisty.getRuntimeProvider(for: chain.chainId) else {
            throw ChainRegistryError.runtimeMetadaUnavailable
        }

        guard let connection = chainRegisty.getConnection(for: chain.chainId) else {
            throw ChainRegistryError.connectionUnavailable
        }

        return EraValidatorService(
            chain: chain,
            storageFacade: storageFacade,
            runtimeCodingService: runtimeService,
            connection: connection,
            providerFactory: substrateDataProviderFactory,
            operationManager: operationManager,
            eventCenter: eventCenter,
            logger: logger
        )
    }

    func createRewardCalculatorService(
        for chainAsset: ChainAsset,
        assetPrecision: Int16,
        validatorService: EraValidatorServiceProtocol,
        collatorOperationFactory: ParachainCollatorOperationFactory?,
        wallet: MetaAccountModel
    ) throws -> RewardCalculatorServiceProtocol {
        guard let runtimeService = chainRegisty.getRuntimeProvider(for: chainAsset.chain.chainId) else {
            throw ChainRegistryError.runtimeMetadaUnavailable
        }

        switch chainAsset.stakingType {
        case .relayChain:
            if chainAsset.chain.isSora {
                return try createSoraRewardCalculator(
                    for: chainAsset,
                    assetPrecision: assetPrecision,
                    validatorService: validatorService,
                    wallet: wallet
                )
            } else {
                return RelaychainRewardCalculatorService(
                    chainAsset: chainAsset,
                    assetPrecision: assetPrecision,
                    eraValidatorsService: validatorService,
                    operationManager: operationManager,
                    providerFactory: substrateDataProviderFactory,
                    runtimeCodingService: runtimeService,
                    stakingDurationFactory: StakingDurationOperationFactory(),
                    storageFacade: storageFacade,
                    logger: logger
                )
            }
        case .paraChain:
            guard let collatorOperationFactory = collatorOperationFactory else {
                throw StakingServiceFactoryError.stakingUnavailable
            }

            return ParachainRewardCalculatorService(
                chainAsset: chainAsset,
                assetPrecision: assetPrecision,
                operationManager: operationManager,
                providerFactory: substrateDataProviderFactory,
                runtimeCodingService: runtimeService,
                storageFacade: storageFacade,
                collatorOperationFactory: collatorOperationFactory
            )
        case .none:
            throw StakingServiceFactoryError.stakingUnavailable
        }
    }

    // MARK: - Private methods

    private func createSoraRewardCalculator(
        for chainAsset: ChainAsset,
        assetPrecision: Int16,
        validatorService: EraValidatorServiceProtocol,
        wallet: MetaAccountModel
    ) throws -> RewardCalculatorServiceProtocol {
        guard let runtimeService = chainRegisty.getRuntimeProvider(for: chainAsset.chain.chainId),
              let connection = chainRegisty.getConnection(for: chainAsset.chain.chainId) else {
            throw ChainRegistryError.runtimeMetadaUnavailable
        }

        let chainRepository = ChainRepositoryFactory().createRepository(
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )

        let operationQueue = OperationQueue()
        operationQueue.qualityOfService = .userInitiated

        let substrateRepositoryFactory = SubstrateRepositoryFactory(
            storageFacade: UserDataStorageFacade.shared
        )
        let accountInfoRepository = substrateRepositoryFactory.createAccountInfoStorageItemRepository()
        let accountInfoFetching = AccountInfoFetching(
            accountInfoRepository: accountInfoRepository,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
        let chainAssetFetching = ChainAssetsFetching(
            chainRepository: AnyDataProviderRepository(chainRepository),
            accountInfoFetching: accountInfoFetching,
            operationQueue: operationQueue,
            meta: wallet
        )

        let storageOperationFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )

        let operationFactory = PolkaswapOperationFactory(
            engine: connection,
            storageRequestFactory: storageOperationFactory,
            runtimeService: runtimeService
        )

        let repositoryFacade = SubstrateDataStorageFacade.shared
        let mapper = PolkaswapSettingMapper()
        let settingsRepository: CoreDataRepository<PolkaswapRemoteSettings, CDPolkaswapRemoteSettings> =
            repositoryFacade.createRepository(
                filter: nil,
                sortDescriptors: [],
                mapper: AnyCoreDataMapper(mapper)
            )

        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )

        return SoraRewardCalculatorService(
            chainAsset: chainAsset,
            assetPrecision: assetPrecision,
            eraValidatorsService: validatorService,
            operationManager: operationManager,
            providerFactory: substrateDataProviderFactory,
            runtimeCodingService: runtimeService,
            stakingDurationFactory: StakingDurationOperationFactory(),
            storageFacade: storageFacade,
            polkaswapOperationFactory: operationFactory,
            chainAssetFetching: chainAssetFetching,
            settingsRepository: AnyDataProviderRepository(settingsRepository),
            logger: Logger.shared,
            storageRequestFactory: requestFactory,
            engine: connection
        )
    }
}
