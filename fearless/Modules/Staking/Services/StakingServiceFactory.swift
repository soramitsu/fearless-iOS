import Foundation
import RobinHood

protocol StakingServiceFactoryProtocol {
    func createEraValidatorService(for chainId: ChainModel.Id) throws -> EraValidatorServiceProtocol
    func createRewardCalculatorService(
        for chainId: ChainModel.Id,
        assetPrecision: Int16,
        validatorService: EraValidatorServiceProtocol
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

    func createEraValidatorService(for chainId: ChainModel.Id) throws -> EraValidatorServiceProtocol {
        guard let runtimeService = chainRegisty.getRuntimeProvider(for: chainId) else {
            throw ChainRegistryError.runtimeMetadaUnavailable
        }

        guard let connection = chainRegisty.getConnection(for: chainId) else {
            throw ChainRegistryError.connectionUnavailable
        }

        return EraValidatorService(
            chainId: chainId,
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
        for chainId: ChainModel.Id,
        assetPrecision: Int16,
        validatorService: EraValidatorServiceProtocol
    ) throws -> RewardCalculatorServiceProtocol {
        guard let runtimeService = chainRegisty.getRuntimeProvider(for: chainId) else {
            throw ChainRegistryError.runtimeMetadaUnavailable
        }

        return RewardCalculatorService(
            chainId: chainId,
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
}
