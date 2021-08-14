import XCTest
@testable import fearless
import Cuckoo
import RobinHood

class RuntimeSyncServiceTests: XCTestCase {
    func testChainRegisterationAndUnregistration() {
        // given

        let storageFacade = SubstrateStorageTestFacade()
        let metadataRepository: CoreDataRepository<RuntimeMetadataItem, CDRuntimeMetadataItem> =
            storageFacade.createRepository()
        let filesOperationFactory = MockRuntimeFilesOperationFactoryProtocol()
        let dataOperationFactory = MockDataOperationFactoryProtocol()
        let eventCenter = MockEventCenterProtocol()
        let connection = MockConnection()

        let syncService = RuntimeSyncService(repository: AnyDataProviderRepository(metadataRepository),
                                             filesOperationFactory: filesOperationFactory,
                                             dataOperationFactory: dataOperationFactory,
                                             eventCenter: eventCenter
        )

        let chainCount = 10
        let chains = ChainModelGenerator.generate(count: chainCount)

        let unregisterChains = Set(chains.prefix(chainCount / 2))
        let remainingChains = Set(chains.suffix(chains.count - unregisterChains.count))

        // when

        chains.forEach { syncService.register(chain: $0, with: connection) }

        // then

        XCTAssertTrue(chains.allSatisfy { syncService.hasChain(with: $0.chainId) })
        XCTAssertTrue(chains.allSatisfy { !syncService.isChainSyncing($0.chainId) })

        // when

        unregisterChains.forEach { syncService.unregister(chainId: $0.chainId) }

        // then

        XCTAssertTrue(remainingChains.allSatisfy { syncService.hasChain(with: $0.chainId) })
        XCTAssertTrue(unregisterChains.allSatisfy { !syncService.hasChain(with: $0.chainId) })
    }

    func testTypesAndMetadataSyncSuccess() throws {
        // given

        let storageFacade = SubstrateStorageTestFacade()
        let metadataRepository: CoreDataRepository<RuntimeMetadataItem, CDRuntimeMetadataItem> =
            storageFacade.createRepository()
        let filesOperationFactory = MockRuntimeFilesOperationFactoryProtocol()
        let dataOperationFactory = MockDataOperationFactoryProtocol()
        let eventCenter = MockEventCenterProtocol()

        let syncService = RuntimeSyncService(repository: AnyDataProviderRepository(metadataRepository),
                                             filesOperationFactory: filesOperationFactory,
                                             dataOperationFactory: dataOperationFactory,
                                             eventCenter: eventCenter
        )

        // when

        let chainCount = 10
        let chains = ChainModelGenerator.generate(count: chainCount)

        let connections = chains.reduce(into: [ChainModel.Id: MockConnection]()) { (storage, chain) in
            storage[chain.chainId] = MockConnection()
        }

        let runtimeMetadataItems = chains.reduce(into: [ChainModel.Id: Data]()) { (storage, chain) in
            storage[chain.chainId] = Data.random(of: 128)!
        }

        // stub chain types file fetch from remote source

        stub(dataOperationFactory) { stub in
            stub.fetchData(from: any()).then { _ in
                let responseData = Data.random(of: 1024)!
                return BaseOperation.createWithResult(responseData)
            }
        }

        // stub chain types file save to disk

        stub(filesOperationFactory) { stub in
            stub.saveChainTypesOperation(for: any(), data: any()).then { (chainId, data) in
                CompoundOperationWrapper.createWithResult(())
            }
        }

        // stub runtime metadata fetch

        connections.forEach { (chainId, connection) in
            stub(connection.internalConnection) { stub in
                stub.callMethod(any(), params: any([String].self), options: any(), completion: any())
                    .then { (_, _, _, completion: ((Result<String, Error>) -> Void)?) in
                        DispatchQueue.global().async {
                            let responseData = runtimeMetadataItems[chainId]!.toHex(includePrefix: true)
                            completion?(.success(responseData))
                        }

                        return (0...UInt16.max).randomElement()!
                }
            }
        }

        let completionExpectation = XCTestExpectation()
        completionExpectation.expectedFulfillmentCount = 2 * chainCount
        completionExpectation.assertForOverFulfill = true

        var syncedTypesChainIds: Set<ChainModel.Id> = Set()
        var syncedMetadataChainIds: Set<ChainModel.Id> = Set()

        // catch all sync completion events

        stub(eventCenter) { stub in
            stub.notify(with: any()).then { event in
                if let syncEvent = event as? RuntimeChainTypesSyncCompleted {
                    syncedTypesChainIds.insert(syncEvent.chainId)
                }

                if let syncEvent = event as? RuntimeMetadataSyncCompleted {
                    syncedMetadataChainIds.insert(syncEvent.chainId)
                }

                completionExpectation.fulfill()
            }
        }

        chains.forEach { chain in
            syncService.register(chain: chain, with: connections[chain.chainId]!)
            syncService.apply(
                version: RuntimeVersion(specVersion: 1, transactionVersion: 1),
                for: chain.chainId
            )

            XCTAssertTrue(syncService.isChainSyncing(chain.chainId))
        }

        // then

        wait(for: [completionExpectation], timeout: 10)

        let expectedChainIds = Set(chains.map { $0.chainId })

        XCTAssertEqual(expectedChainIds, syncedTypesChainIds)
        XCTAssertEqual(expectedChainIds, syncedMetadataChainIds)

        // make sure files are saved

        verify(filesOperationFactory, times(chainCount)).saveChainTypesOperation(for: any(), data: any())

        // make sure metadata is saved for each chain

        let allMetadataOperation = metadataRepository.fetchAllOperation(with: RepositoryFetchOptions())
        OperationQueue().addOperations([allMetadataOperation], waitUntilFinished: true)

        let actualMetadataItems = try allMetadataOperation.extractNoCancellableResultData()
        XCTAssertEqual(actualMetadataItems.count, chainCount)

        for actualMetadataItem in actualMetadataItems {
            XCTAssertEqual(actualMetadataItem.metadata, runtimeMetadataItems[actualMetadataItem.chain]!)
        }
    }

    func testOnlyMetadataSyncSuccess() throws {
        // given

        let storageFacade = SubstrateStorageTestFacade()
        let metadataRepository: CoreDataRepository<RuntimeMetadataItem, CDRuntimeMetadataItem> =
            storageFacade.createRepository()
        let filesOperationFactory = MockRuntimeFilesOperationFactoryProtocol()
        let dataOperationFactory = MockDataOperationFactoryProtocol()
        let eventCenter = MockEventCenterProtocol()

        let syncService = RuntimeSyncService(repository: AnyDataProviderRepository(metadataRepository),
                                             filesOperationFactory: filesOperationFactory,
                                             dataOperationFactory: dataOperationFactory,
                                             eventCenter: eventCenter
        )

        // when

        let chainCount = 10
        let chains = ChainModelGenerator.generate(count: chainCount, withTypes: false)

        let connections = chains.reduce(into: [ChainModel.Id: MockConnection]()) { (storage, chain) in
            storage[chain.chainId] = MockConnection()
        }

        let runtimeMetadataItems = chains.reduce(into: [ChainModel.Id: Data]()) { (storage, chain) in
            storage[chain.chainId] = Data.random(of: 128)!
        }

        // stub runtime metadata fetch

        connections.forEach { (chainId, connection) in
            stub(connection.internalConnection) { stub in
                stub.callMethod(any(), params: any([String].self), options: any(), completion: any())
                    .then { (_, _, _, completion: ((Result<String, Error>) -> Void)?) in
                        DispatchQueue.global().async {
                            let responseData = runtimeMetadataItems[chainId]!.toHex(includePrefix: true)
                            completion?(.success(responseData))
                        }

                        return (0...UInt16.max).randomElement()!
                }
            }
        }

        let completionExpectation = XCTestExpectation()
        completionExpectation.expectedFulfillmentCount = chainCount
        completionExpectation.assertForOverFulfill = true

        var syncedMetadataChainIds: Set<ChainModel.Id> = Set()

        // catch all sync completion events

        stub(eventCenter) { stub in
            stub.notify(with: any()).then { event in
                if let syncEvent = event as? RuntimeMetadataSyncCompleted {
                    syncedMetadataChainIds.insert(syncEvent.chainId)
                }

                completionExpectation.fulfill()
            }
        }

        chains.forEach { chain in
            syncService.register(chain: chain, with: connections[chain.chainId]!)
            syncService.apply(
                version: RuntimeVersion(specVersion: 1, transactionVersion: 1),
                for: chain.chainId
            )

            XCTAssertTrue(syncService.isChainSyncing(chain.chainId))
        }

        // then

        wait(for: [completionExpectation], timeout: 10)

        let expectedChainIds = Set(chains.map { $0.chainId })

        XCTAssertEqual(expectedChainIds, syncedMetadataChainIds)

        // make sure metadata is saved for each chain

        let allMetadataOperation = metadataRepository.fetchAllOperation(with: RepositoryFetchOptions())
        OperationQueue().addOperations([allMetadataOperation], waitUntilFinished: true)

        let actualMetadataItems = try allMetadataOperation.extractNoCancellableResultData()
        XCTAssertEqual(actualMetadataItems.count, chainCount)

        for actualMetadataItem in actualMetadataItems {
            XCTAssertEqual(actualMetadataItem.metadata, runtimeMetadataItems[actualMetadataItem.chain]!)
        }
    }

    func testTypesAndMetadataFailureRetry() throws {
        // given

        let storageFacade = SubstrateStorageTestFacade()
        let metadataRepository: CoreDataRepository<RuntimeMetadataItem, CDRuntimeMetadataItem> =
            storageFacade.createRepository()
        let filesOperationFactory = MockRuntimeFilesOperationFactoryProtocol()
        let dataOperationFactory = MockDataOperationFactoryProtocol()
        let eventCenter = MockEventCenterProtocol()

        let syncService = RuntimeSyncService(repository: AnyDataProviderRepository(metadataRepository),
                                             filesOperationFactory: filesOperationFactory,
                                             dataOperationFactory: dataOperationFactory,
                                             eventCenter: eventCenter
        )

        // when

        let chainCount = 10
        let chains = ChainModelGenerator.generate(count: chainCount)

        let connections = chains.reduce(into: [ChainModel.Id: MockConnection]()) { (storage, chain) in
            storage[chain.chainId] = MockConnection()
        }

        let runtimeMetadataItems = chains.reduce(into: [ChainModel.Id: Data]()) { (storage, chain) in
            storage[chain.chainId] = Data.random(of: 128)!
        }

        // stub chain types file fetch from remote source

        var failureCounterForTypes: Int = 0

        stub(dataOperationFactory) { stub in
            stub.fetchData(from: any()).then { _ in
                if failureCounterForTypes < chainCount {
                    failureCounterForTypes += 1

                    return BaseOperation.createWithError(BaseOperationError.unexpectedDependentResult)
                } else {
                    let responseData = Data.random(of: 1024)!
                    return BaseOperation.createWithResult(responseData)
                }
            }
        }

        // stub chain types file save to disk

        stub(filesOperationFactory) { stub in
            stub.saveChainTypesOperation(for: any(), data: any()).then { (chainId, data) in
                CompoundOperationWrapper.createWithResult(())
            }
        }

        // stub runtime metadata fetch

        var failureCounterForMetadata: Int = 0

        connections.forEach { (chainId, connection) in
            stub(connection.internalConnection) { stub in
                stub.callMethod(any(), params: any([String].self), options: any(), completion: any())
                    .then { (_, _, _, completion: ((Result<String, Error>) -> Void)?) in
                        if failureCounterForMetadata < chainCount {
                            failureCounterForMetadata += 1

                            DispatchQueue.global().async {
                                completion?(.failure(BaseOperationError.unexpectedDependentResult))
                            }

                            return (0...UInt16.max).randomElement()!
                        } else {
                            DispatchQueue.global().async {
                                let responseData = runtimeMetadataItems[chainId]!.toHex(includePrefix: true)
                                completion?(.success(responseData))
                            }

                            return (0...UInt16.max).randomElement()!
                        }
                }
            }
        }

        let completionExpectation = XCTestExpectation()
        completionExpectation.expectedFulfillmentCount = 2 * chainCount
        completionExpectation.assertForOverFulfill = true

        var syncedTypesChainIds: Set<ChainModel.Id> = Set()
        var syncedMetadataChainIds: Set<ChainModel.Id> = Set()

        // catch all sync completion events

        stub(eventCenter) { stub in
            stub.notify(with: any()).then { event in
                if let syncEvent = event as? RuntimeChainTypesSyncCompleted {
                    syncedTypesChainIds.insert(syncEvent.chainId)
                }

                if let syncEvent = event as? RuntimeMetadataSyncCompleted {
                    syncedMetadataChainIds.insert(syncEvent.chainId)
                }

                completionExpectation.fulfill()
            }
        }

        chains.forEach { chain in
            syncService.register(chain: chain, with: connections[chain.chainId]!)
            syncService.apply(
                version: RuntimeVersion(specVersion: 1, transactionVersion: 1),
                for: chain.chainId
            )

            XCTAssertTrue(syncService.isChainSyncing(chain.chainId))
        }

        // then

        wait(for: [completionExpectation], timeout: 10)

        let expectedChainIds = Set(chains.map { $0.chainId })

        XCTAssertEqual(expectedChainIds, syncedTypesChainIds)
        XCTAssertEqual(expectedChainIds, syncedMetadataChainIds)

        // make sure files are tried to be save twice (first time and after retry)

        verify(filesOperationFactory, times(2 * chainCount)).saveChainTypesOperation(
            for: any(),
            data: any()
        )

        // make sure metadata is saved for each chain

        let allMetadataOperation = metadataRepository.fetchAllOperation(with: RepositoryFetchOptions())
        OperationQueue().addOperations([allMetadataOperation], waitUntilFinished: true)

        let actualMetadataItems = try allMetadataOperation.extractNoCancellableResultData()
        XCTAssertEqual(actualMetadataItems.count, chainCount)

        for actualMetadataItem in actualMetadataItems {
            XCTAssertEqual(actualMetadataItem.metadata, runtimeMetadataItems[actualMetadataItem.chain]!)
        }
    }

    func testOnlyTypesFailureRetry() throws {
        // given

        let storageFacade = SubstrateStorageTestFacade()
        let metadataRepository: CoreDataRepository<RuntimeMetadataItem, CDRuntimeMetadataItem> =
            storageFacade.createRepository()
        let filesOperationFactory = MockRuntimeFilesOperationFactoryProtocol()
        let dataOperationFactory = MockDataOperationFactoryProtocol()
        let eventCenter = MockEventCenterProtocol()

        let syncService = RuntimeSyncService(repository: AnyDataProviderRepository(metadataRepository),
                                             filesOperationFactory: filesOperationFactory,
                                             dataOperationFactory: dataOperationFactory,
                                             eventCenter: eventCenter
        )

        // when

        let chainCount = 10
        let chains = ChainModelGenerator.generate(count: chainCount)

        let connections = chains.reduce(into: [ChainModel.Id: MockConnection]()) { (storage, chain) in
            storage[chain.chainId] = MockConnection()
        }

        let runtimeMetadataItems = chains.reduce(into: [ChainModel.Id: Data]()) { (storage, chain) in
            storage[chain.chainId] = Data.random(of: 128)!
        }

        // stub chain types file fetch from remote source

        var failureCounterForTypes: Int = 0

        stub(dataOperationFactory) { stub in
            stub.fetchData(from: any()).then { _ in
                if failureCounterForTypes < chainCount {
                    failureCounterForTypes += 1

                    return BaseOperation.createWithError(BaseOperationError.unexpectedDependentResult)
                } else {
                    let responseData = Data.random(of: 1024)!
                    return BaseOperation.createWithResult(responseData)
                }
            }
        }

        // stub chain types file save to disk

        stub(filesOperationFactory) { stub in
            stub.saveChainTypesOperation(for: any(), data: any()).then { (chainId, data) in
                CompoundOperationWrapper.createWithResult(())
            }
        }

        // stub runtime metadata fetch

        connections.forEach { (chainId, connection) in
            stub(connection.internalConnection) { stub in
                stub.callMethod(any(), params: any([String].self), options: any(), completion: any())
                    .then { (_, _, _, completion: ((Result<String, Error>) -> Void)?) in
                        DispatchQueue.global().async {
                            let responseData = runtimeMetadataItems[chainId]!.toHex(includePrefix: true)
                            completion?(.success(responseData))
                        }

                        return (0...UInt16.max).randomElement()!
                }
            }
        }

        let completionExpectation = XCTestExpectation()
        completionExpectation.expectedFulfillmentCount = 2 * chainCount
        completionExpectation.assertForOverFulfill = true

        var syncedTypesChainIds: Set<ChainModel.Id> = Set()
        var syncedMetadataChainIds: Set<ChainModel.Id> = Set()

        // catch all sync completion events

        stub(eventCenter) { stub in
            stub.notify(with: any()).then { event in
                if let syncEvent = event as? RuntimeChainTypesSyncCompleted {
                    syncedTypesChainIds.insert(syncEvent.chainId)
                }

                if let syncEvent = event as? RuntimeMetadataSyncCompleted {
                    syncedMetadataChainIds.insert(syncEvent.chainId)
                }

                completionExpectation.fulfill()
            }
        }

        chains.forEach { chain in
            syncService.register(chain: chain, with: connections[chain.chainId]!)
            syncService.apply(
                version: RuntimeVersion(specVersion: 1, transactionVersion: 1),
                for: chain.chainId
            )

            XCTAssertTrue(syncService.isChainSyncing(chain.chainId))
        }

        // then

        wait(for: [completionExpectation], timeout: 10)

        let expectedChainIds = Set(chains.map { $0.chainId })

        XCTAssertEqual(expectedChainIds, syncedTypesChainIds)
        XCTAssertEqual(expectedChainIds, syncedMetadataChainIds)

        // make sure files are tried to be save twice (first time and after retry)

        verify(filesOperationFactory, times(2 * chainCount)).saveChainTypesOperation(
            for: any(),
            data: any()
        )

        // make sure metadata requested once

        let completionMatcher: ParameterMatcher<((Result<String, Error>) -> Void)?> = anyClosure()

        for (_, connection) in connections {
            verify(connection.internalConnection, times(1)).callMethod(
                any(),
                params: any([String].self),
                options: any(),
                completion: completionMatcher
            )
        }

        // make sure metadata is saved for each chain

        let allMetadataOperation = metadataRepository.fetchAllOperation(with: RepositoryFetchOptions())
        OperationQueue().addOperations([allMetadataOperation], waitUntilFinished: true)

        let actualMetadataItems = try allMetadataOperation.extractNoCancellableResultData()
        XCTAssertEqual(actualMetadataItems.count, chainCount)

        for actualMetadataItem in actualMetadataItems {
            XCTAssertEqual(actualMetadataItem.metadata, runtimeMetadataItems[actualMetadataItem.chain]!)
        }
    }
}
