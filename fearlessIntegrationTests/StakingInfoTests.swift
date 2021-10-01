import XCTest
@testable import fearless
import SoraKeystore
import RobinHood
import IrohaCrypto

class StakingInfoTests: XCTestCase {
    func testRewardsPolkadot() throws {
        try performCalculatorServiceTest(url: URL(string: "wss://rpc.polkadot.io/")!,
                                         address: "13mAjFVjFDpfa42k2dLdSnUyrSzK8vAySsoudnxX2EKVtfaq",
                                         type: .polkadotMain)
    }

    func testRewardsKusama() throws {
        try performCalculatorServiceTest(url: URL(string: "wss://kusama-rpc.polkadot.io")!,
                                         address: "DayVh23V32nFhvm2WojKx2bYZF1CirRgW2Jti9TXN9zaiH5",
                                         type: .kusamaMain)
    }

    func testRewardsWestend() throws {
        try performCalculatorServiceTest(url: URL(string: "wss://westend-rpc.polkadot.io/")!,
                                         address: "5CDayXd3cDCWpBkSXVsVfhE5bWKyTZdD3D1XUinR1ezS1sGn",
                                         type: .genericSubstrate)
    }

    // MARK: - Private
    private func performCalculatorServiceTest(url: URL,
                                              address: String,
                                              type addressType: SNAddressType) throws {

        // given
        let logger = Logger.shared

        let settings = WebSocketServiceSettings(url: url,
                                                addressType: addressType,
                                                address: address)

        let webSocketService = WebSocketServiceFactory.createService()

        let stakingServiceFactory = StakingServiceFactory(
            chainRegisty: ChainRegistryFacade.sharedRegistry,
            storageFacade: SubstrateDataStorageFacade.shared,
            eventCenter: EventCenter.shared,
            operationManager: OperationManagerFacade.sharedManager
        )

        let runtimeService = ChainRegistryFacade.sharedRegistry.getRuntimeProvider(
            for: addressType.chain.genesisHash
        )!

        let validatorService = try stakingServiceFactory.createEraValidatorService(
            for: addressType.chain.genesisHash
        )

        let rewardCalculatorService = try stakingServiceFactory.createRewardCalculatorService(
            for: addressType.chain.genesisHash,
            assetPrecision: addressType.precision,
            validatorService: validatorService
        )

        // when
        webSocketService.update(settings: settings)

        webSocketService.setup()
        runtimeService.setup()

        let chain = addressType.chain

        validatorService.setup()
        rewardCalculatorService.setup()

        let validatorsOperation = validatorService.fetchInfoOperation()
        let calculatorOperation = rewardCalculatorService.fetchCalculatorOperation()

        let mapOperation: BaseOperation<[(String, Decimal)]> = ClosureOperation {
            let info = try validatorsOperation.extractNoCancellableResultData()
            let calculator = try calculatorOperation.extractNoCancellableResultData()

            let factory = SS58AddressFactory()

            let rewards: [(String, Decimal)] = try info.validators.map { validator in
                let reward = try calculator
                    .calculateValidatorReturn(validatorAccountId: validator.accountId,
                                              isCompound: false,
                                              period: .year)

                let address = try factory.address(fromPublicKey: AccountIdWrapper(rawData: validator.accountId),
                                                  type: chain.addressType)
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
    }
}
