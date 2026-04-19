import XCTest
@testable import fearless
import SSFModels
import SoraKeystore
import RobinHood
import IrohaCrypto
import SSFUtils

class StakingInfoTests: XCTestCase {
    func testRewardsPolkadot() throws {
        try performCalculatorServiceTest(
            chainName: "Polkadot",
            assetSymbol: "dot",
            address: "13mAjFVjFDpfa42k2dLdSnUyrSzK8vAySsoudnxX2EKVtfaq",
            expectedPrefix: 0
        )
    }

    func testRewardsKusama() throws {
        try performCalculatorServiceTest(
            chainName: "Kusama",
            assetSymbol: "ksm",
            address: "DayVh23V32nFhvm2WojKx2bYZF1CirRgW2Jti9TXN9zaiH5",
            expectedPrefix: 2
        )
    }

    func testRewardsWestend() throws {
        try performCalculatorServiceTest(
            chainName: "Westend",
            assetSymbol: "wnd",
            address: "5CDayXd3cDCWpBkSXVsVfhE5bWKyTZdD3D1XUinR1ezS1sGn",
            expectedPrefix: 42
        )
    }

    // MARK: - Private
    private func performCalculatorServiceTest(
        chainName: String,
        assetSymbol: String,
        address: String,
        expectedPrefix: UInt16
    ) throws {
        let logger = Logger.shared
        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)

        guard !chainRegistry.availableChains.isEmpty else {
            throw XCTSkip("Chain registry integration setup is unavailable in the current environment")
        }

        guard
            let chain = chainRegistry.availableChains.first(where: { $0.name == chainName }),
            let asset = chain.assets.first(where: { $0.symbol.lowercased() == assetSymbol.lowercased() })
                ?? chain.assets.first(where: \.isUtility)
        else {
            throw XCTSkip("Missing integration test chain or asset for \(chainName)")
        }

        let chainAsset = ChainAsset(chain: chain, asset: asset)
        let chainFormat = ChainFormat.substrate(expectedPrefix)
        let assetPrecision = Int16(asset.precision)

        let stakingServiceFactory = StakingServiceFactory(
            chainRegisty: chainRegistry,
            storageFacade: storageFacade,
            eventCenter: EventCenter.shared,
            operationManager: OperationManager(),
            logger: logger
        )

        let validatorService = try stakingServiceFactory.createEraValidatorService(
            for: chainAsset.chain
        )
        
        let operationManager: OperationManagerProtocol = OperationManager()
        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )
        
        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId),
              let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId)
        else {
            throw ChainRegistryError.connectionUnavailable
        }
        
        let identityOperationFactory = IdentityOperationFactory(requestFactory: storageRequestFactory)
        let rewardOperationFactory = SubqueryRewardOperationFactory(url: chainAsset.chain.externalApi?.staking?.url)
        let collatorOperationFactory = ParachainCollatorOperationFactory(
            asset: chainAsset.asset,
            chain: chainAsset.chain,
            storageRequestFactory: storageRequestFactory,
            identityOperationFactory: identityOperationFactory,
            subqueryOperationFactory: rewardOperationFactory,
            chainRegistry: chainRegistry
        )

        let rewardCalculatorService = try stakingServiceFactory.createRewardCalculatorService(
            for: chainAsset,
            assetPrecision: assetPrecision,
            validatorService: validatorService, collatorOperationFactory: collatorOperationFactory
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
            for: chainAsset.chain.chainId,
            queue: nil,
            closure: nil,
            stakingType: chainAsset.stakingType
        )

        // when

        validatorService.setup()
        rewardCalculatorService.setup()

        let validatorsOperation = validatorService.fetchInfoOperation()
        let calculatorOperation = rewardCalculatorService.fetchCalculatorOperation()

        let mapOperation: BaseOperation<[(String, Decimal)]> = ClosureOperation {
            let info = try validatorsOperation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            let calculator = try calculatorOperation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)

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

        let result = try mapOperation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        logger.info("Reward: \(result)")

        remoteStakingSubcriptionService.detachFromGlobalData(
            for: subscriptionId!,
            chainId: chainAsset.chain.chainId,
            queue: nil,
            closure: nil,
            stakingType: chainAsset.stakingType
        )
    }
}
