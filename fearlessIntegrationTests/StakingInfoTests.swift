import XCTest
@testable import fearless
import SoraKeystore
import RobinHood
import IrohaCrypto
import FearlessUtils

class StakingInfoTests: XCTestCase {
    func testRewardsPolkadot() throws {
        let asset = ChainModelGenerator.generateAssetWithId("887a17c7-1370-4de0-97dd-5422e294fa75", symbol: "dot")
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let chainAsset = ChainAsset(chain: chain, asset: asset)
        
        try performCalculatorServiceTest(
            address: "13mAjFVjFDpfa42k2dLdSnUyrSzK8vAySsoudnxX2EKVtfaq",
            chainAsset: chainAsset,
            chainFormat: .substrate(0),
            assetPrecision: 10
        )
    }

    func testRewardsKusama() throws {
        let asset = ChainModelGenerator.generateAssetWithId("1e0c2ec6-935f-49bd-a854-5e12ee6c9f1b", symbol: "ksm")
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 2)
        let chainAsset = ChainAsset(chain: chain, asset: asset)
        
        try performCalculatorServiceTest(
            address: "DayVh23V32nFhvm2WojKx2bYZF1CirRgW2Jti9TXN9zaiH5",
            chainAsset: chainAsset,
            chainFormat: .substrate(2),
            assetPrecision: 12
        )
    }

    func testRewardsWestend() throws {
        let asset = ChainModelGenerator.generateAssetWithId("a3868e1b-922e-42d4-b73e-b41712f0843c", symbol: "wnd")
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 42)
        let chainAsset = ChainAsset(chain: chain, asset: asset)
        
        try performCalculatorServiceTest(
            address: "5CDayXd3cDCWpBkSXVsVfhE5bWKyTZdD3D1XUinR1ezS1sGn",
            chainAsset: chainAsset,
            chainFormat: .substrate(42),
            assetPrecision: 12
        )
    }

    // MARK: - Private
    private func performCalculatorServiceTest(
        address: String,
        chainAsset: ChainAsset,
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
            for: chainAsset.chain
        )
        
        let operationManager = OperationManagerFacade.sharedManager
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
            runtimeService: runtimeService,
            engine: connection,
            identityOperationFactory: identityOperationFactory,
            subqueryOperationFactory: rewardOperationFactory
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
            chainId: chainAsset.chain.chainId,
            queue: nil,
            closure: nil,
            stakingType: chainAsset.stakingType
        )
    }
}
