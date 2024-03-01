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
        collatorOperationFactory: ParachainCollatorOperationFactory?
    ) throws -> RewardCalculatorServiceProtocol
}

final class StakingServiceFactory: StakingServiceFactoryProtocol {
    let chainRegistry: ChainRegistryProtocol
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
        chainRegistry = chainRegisty
        self.storageFacade = storageFacade
        self.eventCenter = eventCenter
        self.operationManager = operationManager
        self.logger = logger
    }

    func createEraValidatorService(for chain: ChainModel) throws -> EraValidatorServiceProtocol {
        EraValidatorService(
            chain: chain,
            storageFacade: storageFacade,
            providerFactory: substrateDataProviderFactory,
            operationManager: operationManager,
            eventCenter: eventCenter,
            chainRegistry: chainRegistry,
            logger: logger
        )
    }

    func createRewardCalculatorService(
        for chainAsset: ChainAsset,
        assetPrecision: Int16,
        validatorService: EraValidatorServiceProtocol,
        collatorOperationFactory: ParachainCollatorOperationFactory?
    ) throws -> RewardCalculatorServiceProtocol {
        switch chainAsset.stakingType {
        case .relaychain:
            if chainAsset.chain.isReef {
                return try createReefRewardCalculator(
                    chainAsset: chainAsset,
                    validatorService: validatorService
                )
            }

            return InflationRewardCalculatorService(
                chainAsset: chainAsset,
                assetPrecision: assetPrecision,
                eraValidatorsService: validatorService,
                operationManager: operationManager,
                providerFactory: substrateDataProviderFactory,
                chainRegistry: chainRegistry,
                stakingDurationFactory: StakingDurationOperationFactory(),
                storageFacade: storageFacade,
                logger: logger
            )
        case .parachain:
            guard let collatorOperationFactory = collatorOperationFactory else {
                throw StakingServiceFactoryError.stakingUnavailable
            }

            return ParachainRewardCalculatorService(
                chainAsset: chainAsset,
                assetPrecision: assetPrecision,
                operationManager: operationManager,
                providerFactory: substrateDataProviderFactory,
                chainRegistry: chainRegistry,
                storageFacade: storageFacade,
                collatorOperationFactory: collatorOperationFactory
            )
        case .sora:
            return try createSoraRewardCalculator(
                for: chainAsset,
                assetPrecision: assetPrecision,
                validatorService: validatorService
            )
        case .ternoa:
            let requestFactory = StorageRequestFactory(
                remoteFactory: StorageKeyFactory(),
                operationManager: operationManager
            )

            return PortionRewardCalculatorService(
                chainAsset: chainAsset,
                assetPrecision: assetPrecision,
                eraValidatorsService: validatorService,
                operationManager: operationManager,
                providerFactory: substrateDataProviderFactory,
                chainRegistry: chainRegistry,
                stakingDurationFactory: StakingDurationOperationFactory(),
                storageFacade: storageFacade,
                storageRequestFactory: requestFactory
            )
        case .none:
            throw StakingServiceFactoryError.stakingUnavailable
        }
    }

    // MARK: - Private methods

    private func createReefRewardCalculator(
        chainAsset: ChainAsset,
        validatorService: EraValidatorServiceProtocol
    ) throws -> RewardCalculatorServiceProtocol {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId) else {
            throw ChainRegistryError.runtimeMetadaUnavailable
        }

        guard let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId) else {
            throw ChainRegistryError.connectionUnavailable
        }

        let operationManager = OperationManagerFacade.sharedManager
        let storageRequestPerformer = StorageRequestPerformerDefault(
            runtimeService: runtimeService,
            connection: connection
        )

        return ReefRewardCalculatorService(
            chainAsset: chainAsset,
            eraValidatorsService: validatorService,
            operationManager: operationManager,
            chainRegistry: chainRegistry,
            logger: logger,
            storageRequestPerformer: storageRequestPerformer
        )
    }

    private func createSoraRewardCalculator(
        for chainAsset: ChainAsset,
        assetPrecision: Int16,
        validatorService: EraValidatorServiceProtocol
    ) throws -> RewardCalculatorServiceProtocol {
        let chainRepository = ChainRepositoryFactory().createRepository(
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )

        let operationQueue = OperationQueue()
        operationQueue.qualityOfService = .userInitiated

        let chainAssetFetching = ChainAssetsFetching(
            chainRepository: AnyDataProviderRepository(chainRepository),
            operationQueue: operationQueue
        )

        let storageOperationFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )

        let operationFactory = PolkaswapOperationFactory(
            storageRequestFactory: storageOperationFactory,
            chainRegistry: chainRegistry,
            chainId: chainAsset.chain.chainId
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
            chainRegistry: chainRegistry,
            stakingDurationFactory: StakingDurationOperationFactory(),
            storageFacade: storageFacade,
            polkaswapOperationFactory: operationFactory,
            chainAssetFetching: chainAssetFetching,
            settingsRepository: AnyDataProviderRepository(settingsRepository),
            logger: Logger.shared,
            storageRequestFactory: requestFactory
        )
    }
}
