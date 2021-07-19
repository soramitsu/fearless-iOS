import XCTest
import RobinHood
import FearlessUtils
import SoraKeystore
@testable import fearless

class CountdownTests: XCTestCase, RuntimeConstantFetching {

    func testService() {
        let operationManager = OperationManagerFacade.sharedManager

        WebSocketService.shared.setup()
        let connection = WebSocketService.shared.connection!
        let runtimeService = RuntimeRegistryFacade.sharedService
        runtimeService.setup()

        let keyFactory = StorageKeyFactory()
        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: keyFactory,
            operationManager: operationManager
        )


        let service = EraCountdownService(
            chain: .westend,
            runtimeCodingService: runtimeService,
            storageRequestFactory: storageRequestFactory,
            engine: connection
        )

        let expectation = XCTestExpectation()
        let operation = service.fetchCountdownOperationWrapper()
        operation.targetOperation.completionBlock = {
            do {
                let res = try operation.targetOperation.extractNoCancellableResultData()
                print(res)
                expectation.fulfill()
            } catch {
                XCTFail(error.localizedDescription)
            }
        }

        operationManager.enqueue(operations: operation.allOperations, in: .transient)

        wait(for: [expectation], timeout: 10)
    }

    func testNumberOfSessionsPerEra() {
        let runtimeCodingService = try! RuntimeCodingServiceStub.createWestendService()
        let operationManager = OperationManagerFacade.sharedManager

        let sessionExpectation = XCTestExpectation()
        fetchConstant(
            for: .eraLength,
            runtimeCodingService: runtimeCodingService,
            operationManager: operationManager
        ) { (result: Result<SessionIndex, Error>) in
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
        let wrapper: CompoundOperationWrapper<[StorageResponse<StringScaleMapper<SessionIndex>>]> =
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

    func testEraStartSessionIndex() {
        let operationManager = OperationManagerFacade.sharedManager
        let keyFactory = StorageKeyFactory()

        WebSocketService.shared.setup()
        let connection = WebSocketService.shared.connection!
        let runtimeService = RuntimeRegistryFacade.sharedService
        runtimeService.setup()

        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()
        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: keyFactory,
            operationManager: operationManager
        )

        let eraStartSessionIndexExpectation = XCTestExpectation()

        let wrapper: CompoundOperationWrapper<[StorageResponse<StringScaleMapper<SessionIndex>>]> =
            storageRequestFactory.queryItems(
                engine: connection,
                keyParams: { [StringScaleMapper(value: "3938")] },
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                storagePath: .eraStartSessionIndex
            )

        wrapper.addDependency(operations: [codingFactoryOperation])

        wrapper.targetOperation.completionBlock = {
            do {
                let value = try wrapper.targetOperation.extractNoCancellableResultData()
                    .first?.value?.value
                eraStartSessionIndexExpectation.fulfill()
            } catch {
                XCTFail(error.localizedDescription)
            }
        }

        operationManager.enqueue(
            operations: [codingFactoryOperation] + wrapper.allOperations,
            in: .transient
        )

        wait(for: [eraStartSessionIndexExpectation], timeout: 10)
    }

    func testFetchCurrentSlot() {
        let operationManager = OperationManagerFacade.sharedManager
        let keyFactory = StorageKeyFactory()

        WebSocketService.shared.setup()
        let connection = WebSocketService.shared.connection!
        let runtimeService = RuntimeRegistryFacade.sharedService
        runtimeService.setup()

        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()
        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: keyFactory,
            operationManager: operationManager
        )

        let currentSlotWrapper: CompoundOperationWrapper<[StorageResponse<StringScaleMapper<Slot>>]> =
            storageRequestFactory.queryItems(
                engine: connection,
                keys: { [try keyFactory.currentSlot()] },
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                storagePath: .currentSlot
            )
        currentSlotWrapper.addDependency(operations: [codingFactoryOperation])

        let currentSlotExpectation = XCTestExpectation()
        currentSlotWrapper.targetOperation.completionBlock = {
            do {
                let value = try currentSlotWrapper.targetOperation.extractNoCancellableResultData()
                    .first?.value?.value
                currentSlotExpectation.fulfill()
            } catch {
                XCTFail(error.localizedDescription)
            }
        }

        let genesisSlotWrapper: CompoundOperationWrapper<[StorageResponse<StringScaleMapper<Slot>>]> =
            storageRequestFactory.queryItems(
                engine: connection,
                keys: { [try keyFactory.genesisSlot()] },
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                storagePath: .genesisSlot
            )
        genesisSlotWrapper.addDependency(operations: [codingFactoryOperation])

        let genesisSlotExpectation = XCTestExpectation()
        genesisSlotWrapper.targetOperation.completionBlock = {
            do {
                let value = try genesisSlotWrapper.targetOperation.extractNoCancellableResultData()
                    .first?.value?.value
                genesisSlotExpectation.fulfill()
            } catch {
                XCTFail(error.localizedDescription)
            }
        }

        operationManager.enqueue(
            operations: [codingFactoryOperation] + currentSlotWrapper.allOperations + genesisSlotWrapper.allOperations,
            in: .transient
        )

        wait(for: [currentSlotExpectation, genesisSlotExpectation], timeout: 10)
    }
}
