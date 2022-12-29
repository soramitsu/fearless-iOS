import Foundation
import RobinHood

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
        collatorOperationFactory: ParachainCollatorOperationFactory?
    ) throws -> RewardCalculatorServiceProtocol {
        guard let runtimeService = chainRegisty.getRuntimeProvider(for: chainAsset.chain.chainId) else {
            throw ChainRegistryError.runtimeMetadaUnavailable
        }

        switch chainAsset.stakingType {
        case .relayChain:
            return RewardCalculatorService(
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
}
