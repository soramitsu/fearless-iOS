import XCTest
import RobinHood
import FearlessUtils
import SoraKeystore
@testable import fearless

class CountdownTests: XCTestCase, RuntimeConstantFetching {

    func testNumberOfSessionsPerEra() {
        let runtimeCodingService = try! RuntimeCodingServiceStub.createWestendService()
        let operationManager = OperationManagerFacade.sharedManager

        let sessionExpectation = XCTestExpectation()
        fetchConstant(
            for: .eraLength,
            runtimeCodingService: runtimeCodingService,
            operationManager: operationManager
        ) { (result: Result<UInt32, Error>) in
            switch result {
            case let .success(index):
                if index == 6 {
                    sessionExpectation.fulfill()
                } else {
                    XCTFail("""
                        SessionsPerEra for westend has been changed.
                        See https://github.com/paritytech/polkadot/blob/956d6ae183a0b7f662d37bbbd251b64423f9701c/runtime/westend/src/lib.rs#L418
                    """)
                }
            case let .failure(error):
                XCTFail(error.localizedDescription)
            }
        }

        wait(for: [sessionExpectation], timeout: 10)
    }

    func testNumberOfSlotsPerSession() {
        let runtimeCodingService = try! RuntimeCodingServiceStub.createWestendService()
        let operationManager = OperationManagerFacade.sharedManager

        let sessionExpectation = XCTestExpectation()
        fetchConstant(
            for: .sessionLength,
            runtimeCodingService: runtimeCodingService,
            operationManager: operationManager
        ) { (result: Result<UInt64, Error>) in
            switch result {
            case let .success(index):
                if index == 600 {
                    sessionExpectation.fulfill()
                } else {
                    XCTFail("""
                        EpochDuration for westend has been changed.
                        See https://github.com/paritytech/polkadot/blob/8a6af4412ffc6d327775310c9b4ff527f3345958/runtime/westend/src/constants.rs#L36
                    """)
                }
            case let .failure(error):
                XCTFail(error.localizedDescription)
            }
        }

        wait(for: [sessionExpectation], timeout: 10)
    }

    func testCurrentSessionIndex() {
        let operationManager = OperationManagerFacade.sharedManager
        let keyFactory = StorageKeyFactory()

        let settings = SettingsManager.shared
        let assetId = WalletAssetId.westend
        let chain = assetId.chain!

        try! AccountCreationHelper.createAccountFromMnemonic(
            cryptoType: .sr25519,
            networkType: chain,
            keychain: Keychain(),
            settings: settings
        )

        WebSocketService.shared.setup()
        let connection = WebSocketService.shared.connection!
        let runtimeService = RuntimeRegistryFacade.sharedService
        runtimeService.setup()

        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()
        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: keyFactory,
            operationManager: operationManager
        )

        let sessionExpectation = XCTestExpectation()
        let wrapper: CompoundOperationWrapper<[StorageResponse<StringScaleMapper<UInt32>>]> =
            storageRequestFactory.queryItems(
                engine: connection,
                keys: { [try keyFactory.currentSessionIndex()] },
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                storagePath: .currentSessionIndex
            )

        wrapper.addDependency(operations: [codingFactoryOperation])

        wrapper.targetOperation.completionBlock = {
            do {
                let value = try wrapper.targetOperation.extractNoCancellableResultData()
                    .first?.value?.value
                sessionExpectation.fulfill()
            } catch {
                XCTFail(error.localizedDescription)
            }
        }

        operationManager.enqueue(
            operations: [codingFactoryOperation] + wrapper.allOperations,
            in: .transient
        )
        wait(for: [sessionExpectation], timeout: 5)
    }
}
