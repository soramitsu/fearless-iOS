import XCTest
@testable import fearless
import SoraKeystore
import RobinHood
import IrohaCrypto

class StakingInfoTests: XCTestCase {
    func testRewardsPolkadot() throws {
        try performCalculatorServiceTest(
            address: "13mAjFVjFDpfa42k2dLdSnUyrSzK8vAySsoudnxX2EKVtfaq",
            chainId: Chain.polkadot.genesisHash,
            chainFormat: .substrate(0),
            assetPrecision: 10
        )
    }

    func testRewardsKusama() throws {
        try performCalculatorServiceTest(
            address: "DayVh23V32nFhvm2WojKx2bYZF1CirRgW2Jti9TXN9zaiH5",
            chainId: Chain.kusama.genesisHash,
            chainFormat: .substrate(2),
            assetPrecision: 12
        )
    }

    func testRewardsWestend() throws {
        try performCalculatorServiceTest(
            address: "5CDayXd3cDCWpBkSXVsVfhE5bWKyTZdD3D1XUinR1ezS1sGn",
            chainId: Chain.westend.genesisHash,
            chainFormat: .substrate(42),
            assetPrecision: 12
        )
    }

    // MARK: - Private
    private func performCalculatorServiceTest(
        address: String,
        chainId: ChainModel.Id,
        chainFormat: ChainFormat,
        assetPrecision: Int16
    ) throws {

        // given
        let logger = Logger.shared

        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)

        let stakingServiceFactory = StakingServiceFactory(
            chainRegisty: chainRegistry,
            storageFacade: storageFacade,
            eventCenter: EventCenter.shared,
            operationManager: OperationManagerFacade.sharedManager,
            logger: logger
        )

        let validatorService = try stakingServiceFactory.createEraValidatorService(
            for: chainId
        )

        let rewardCalculatorService = try stakingServiceFactory.createRewardCalculatorService(
            for: chainId,
            assetPrecision: assetPrecision,
            validatorService: validatorService
        )

        let chainItemRepository = SubstrateRepositoryFactory(
            storageFacade: storageFacade
        ).createChainStorageItemRepository()

        let remoteStakingSubcriptionService = StakingRemoteSubscriptionService(
            chainRegistry: chainRegistry, repository: AnyDataProviderRepository(chainItemRepository),
            operationManager: OperationManager(),
            logger: logger
        )

        let subscriptionId = remoteStakingSubcriptionService.attachToGlobalData(
            for: chainId,
            queue: nil,
            closure: nil
        )

        // when

        validatorService.setup()
        rewardCalculatorService.setup()

        let validatorsOperation = validatorService.fetchInfoOperation()
        let calculatorOperation = rewardCalculatorService.fetchCalculatorOperation()

        let mapOperation: BaseOperation<[(String, Decimal)]> = ClosureOperation {
            let info = try validatorsOperation.extractNoCancellableResultData()
            let calculator = try calculatorOperation.extractNoCancellableResultData()

            let rewards: [(String, Decimal)] = try info.validators.map { validator in
                let reward = try calculator
                    .calculateValidatorReturn(validatorAccountId: validator.accountId,
                                              isCompound: false,
                                              period: .year)

                let address = try validator.accountId.toAddress(using: chainFormat)
                return (address, reward * 100.0)
            }

            return rewards
        }

        mapOperation.addDependency(validatorsOperation)
        mapOperation.addDependency(calculatorOperation)

        // then

        let operationQueue = OperationQueue()
        operationQueue.addOperations([validatorsOperation, calculatorOperation, mapOperation],
                                     waitUntilFinished: true)

        let result = try mapOperation.extractNoCancellableResultData()
        logger.info("Reward: \(result)")

        remoteStakingSubcriptionService.detachFromGlobalData(
            for: subscriptionId!,
            chainId: chainId,
            queue: nil,
            closure: nil
        )
    }
}
