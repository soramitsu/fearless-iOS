import XCTest
import RobinHood
import SoraFoundation
import SSFModels
import SSFUtils
@testable import fearless

final class ChainSyncServiceCompatibilityTests: XCTestCase {
    func testAppOwnedUniversalChainsAreAlwaysPresentAndOverrideRemoteCollisions() throws {
        let remote = makeValidChain(generatingAssets: 1, addressPrefix: 42)
        let collidingBitcoin = copy(
            remote,
            chainId: UniversalWalletRegistry.bitcoinMainnet.chainId,
            name: "Untrusted Bitcoin replacement"
        )
        let collidingTaira = copy(
            remote,
            chainId: UniversalWalletRegistry.taira.id,
            name: "Untrusted Taira replacement"
        )

        let merged = ChainSyncService.mergingAppOwnedProductionChains(
            into: [remote, collidingBitcoin, collidingTaira]
        )
        let bitcoinRows = merged.filter {
            $0.chainId == UniversalWalletRegistry.bitcoinMainnet.chainId
        }
        let sanitized = try ChainSyncService.sanitizingRemoteChains(merged)

        XCTAssertEqual(bitcoinRows, [UniversalWalletRegistry.bitcoinMainnetChainModel])
        XCTAssertEqual(
            sanitized.first(where: {
                $0.chainId == UniversalWalletRegistry.bitcoinMainnet.chainId
            }),
            UniversalWalletRegistry.bitcoinMainnetChainModel
        )
        XCTAssertEqual(
            merged.filter {
                UniversalWalletChainAccountSupport.chainId(
                    $0.chainId,
                    matches: UniversalWalletRegistry.taira.chainId
                )
            },
            [UniversalWalletRegistry.tairaChainModel]
        )
        XCTAssertEqual(
            sanitized.first(where: {
                $0.chainId == UniversalWalletRegistry.taira.chainId
            }),
            UniversalWalletRegistry.tairaChainModel
        )
        XCTAssertTrue(merged.contains(where: { $0.chainId == remote.chainId }))
    }

    func testSuccessfulSyncDeletesObsoleteBitcoinAliasAndPersistsCanonicalChain() throws {
        let remote = makeValidChain(generatingAssets: 1, addressPrefix: 42)
        let bitcoinAlias = copy(
            UniversalWalletRegistry.bitcoinMainnetChainModel,
            chainId: UniversalWalletRegistry.bitcoinMainnet.id
        )
        let tairaAlias = copy(
            UniversalWalletRegistry.tairaChainModel,
            chainId: UniversalWalletRegistry.taira.id
        )
        let staleTairaXor = AssetModel(
            id: "61CtjvNd9T3THAR65GsMVHr82Bjc",
            name: "xor",
            symbol: "XOR",
            precision: 9,
            isUtility: true,
            isNative: true
        )
        let staleCanonicalTaira = copy(
            UniversalWalletRegistry.tairaChainModel,
            assets: [staleTairaXor]
        )
        let repository = ScriptedChainRepository(
            localChains: [bitcoinAlias, tairaAlias, staleCanonicalTaira]
        )
        let eventCenter = RecordingChainSyncEventCenter()
        let remoteFetchRelease = DispatchSemaphore(value: 0)
        defer { remoteFetchRelease.signal() }
        let remoteFetchStarted = expectation(
            description: "remote fetch starts after app-owned catalog persistence"
        )
        let completionExpectation = expectation(
            description: "canonical app-owned catalog persisted"
        )
        eventCenter.onEvent = { event in
            if event is ChainSyncDidComplete {
                completionExpectation.fulfill()
            }
        }
        let dataFactory = CountingDataOperationFactory(
            data: try JSONEncoder().encode([remote]),
            firstFetchGate: remoteFetchRelease,
            onFirstFetchStart: remoteFetchStarted.fulfill
        )
        let service = makeService(
            dataFetchFactory: dataFactory,
            repository: AnyDataProviderRepository(repository),
            eventCenter: eventCenter
        )

        service.syncUp()

        wait(for: [remoteFetchStarted], timeout: 1)
        XCTAssertEqual(repository.saveCallCount, 1)
        XCTAssertEqual(
            repository.savedModels,
            UniversalWalletRegistry.appOwnedProductionChains
        )
        XCTAssertEqual(
            Set(repository.deletedIdentifiers),
            Set([bitcoinAlias.chainId, tairaAlias.chainId])
        )
        XCTAssertEqual(
            eventCenter.lastUpdatedChains,
            UniversalWalletRegistry.appOwnedProductionChains
        )
        XCTAssertEqual(eventCenter.failureCount, 0)
        XCTAssertEqual(eventCenter.completionCount, 0)

        remoteFetchRelease.signal()
        wait(for: [completionExpectation], timeout: 1)
        XCTAssertEqual(
            Set(repository.deletedIdentifiers),
            Set([bitcoinAlias.chainId, tairaAlias.chainId])
        )
        XCTAssertTrue(
            repository.savedModels.contains(
                UniversalWalletRegistry.bitcoinMainnetChainModel
            )
        )
        XCTAssertTrue(
            repository.savedModels.contains(
                UniversalWalletRegistry.tairaChainModel
            )
        )
        let persistedTaira = try XCTUnwrap(
            repository.savedModels.first {
                $0.chainId == UniversalWalletRegistry.taira.chainId
            }
        )
        XCTAssertEqual(
            persistedTaira.assets.map(\.id),
            [UniversalWalletRegistry.tairaNativeXorAssetDefinitionId]
        )
        XCTAssertEqual(
            persistedTaira.assets.first?.precision,
            UniversalWalletRegistry.tairaNativeXorPrecision
        )
        XCTAssertEqual(eventCenter.failureCount, 0)
        XCTAssertEqual(eventCenter.completionCount, 1)
    }

    func testCoerceChainsPayloadForCompatibilityNormalizesBlockscoutTypes() throws {
        let payload: [[String: Any]] = [[
            "externalApi": [
                "history": [
                    "type": "klaytn",
                    "url": "https://blockscout.example/api"
                ],
                "staking": [
                    "type": "blockscout",
                    "url": "https://blockscout.example/staking"
                ],
                "explorers": [
                    [
                        "type": "blockscout",
                        "url": "https://blockscout.example/explorer"
                    ],
                    [
                        "type": "etherscan",
                        "url": "https://etherscan.io"
                    ]
                ]
            ]
        ]]

        let data = try JSONSerialization.data(withJSONObject: payload, options: [])
        let coerced = try ChainSyncService.coerceChainsPayloadForCompatibility(data)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: coerced, options: []) as? [[String: Any]])

        let externalApi = try XCTUnwrap(json.first?["externalApi"] as? [String: Any])
        let history = try XCTUnwrap(externalApi["history"] as? [String: Any])
        let staking = try XCTUnwrap(externalApi["staking"] as? [String: Any])
        let explorers = try XCTUnwrap(externalApi["explorers"] as? [[String: Any]])

        XCTAssertEqual(history["type"] as? String, ChainSyncService.historyExplorerCompatibilityType)
        XCTAssertEqual(staking["type"] as? String, ChainSyncService.stakingExplorerCompatibilityType)
        XCTAssertEqual(explorers.first?["type"] as? String, ChainSyncService.genericExplorerCompatibilityType)
        XCTAssertEqual(explorers.last?["type"] as? String, "etherscan")
    }

    func testPreservingLocalNodePreferencesKeepsCustomAndSelectedNodes() throws {
        let remoteChain = makeValidChain(
            generatingAssets: 1,
            addressPrefix: 42
        )
        let customNode = ChainNodeModel(
            url: try XCTUnwrap(URL(string: "wss://user-node.example")),
            name: "My private node",
            apikey: nil
        )
        let localChain = remoteChain
            .replacingCustomNodes([customNode])
            .replacingSelectedNode(customNode)

        let mergedChains = ChainSyncService.preservingLocalNodePreferences(
            remoteChains: [remoteChain],
            localChains: [localChain]
        )

        let mergedChain = try XCTUnwrap(mergedChains.first)
        XCTAssertEqual(mergedChain.customNodes, Set([customNode]))
        XCTAssertEqual(mergedChain.selectedNode, customNode)
        XCTAssertNil(remoteChain.customNodes)
        XCTAssertNil(remoteChain.selectedNode)
    }

    func testPreservingLocalNodePreferencesDoesNotApplyPreferencesToAnotherChain() throws {
        let remoteChains = ChainModelGenerator.generate(count: 2)
        let customNode = ChainNodeModel(
            url: try XCTUnwrap(URL(string: "wss://user-node.example")),
            name: "My private node",
            apikey: nil
        )
        let localChain = remoteChains[0]
            .replacingCustomNodes([customNode])
            .replacingSelectedNode(customNode)

        let mergedChains = ChainSyncService.preservingLocalNodePreferences(
            remoteChains: remoteChains,
            localChains: [localChain]
        )

        XCTAssertEqual(mergedChains[0].customNodes, Set([customNode]))
        XCTAssertEqual(mergedChains[0].selectedNode, customNode)
        XCTAssertNil(mergedChains[1].customNodes)
        XCTAssertNil(mergedChains[1].selectedNode)
    }

    func testPreservingLocalNodePreferencesRejectsRemoteCustomNodeInjection() throws {
        let localChain = makeValidChain(
            generatingAssets: 1,
            addressPrefix: 42
        )
        let injectedNode = ChainNodeModel(
            url: try XCTUnwrap(URL(string: "wss://untrusted-remote-node.example")),
            name: "Injected node",
            apikey: nil
        )
        let remoteChain = localChain
            .replacingCustomNodes([injectedNode])
            .replacingSelectedNode(injectedNode)

        let mergedChains = ChainSyncService.preservingLocalNodePreferences(
            remoteChains: [remoteChain],
            localChains: [localChain]
        )

        let mergedChain = try XCTUnwrap(mergedChains.first)
        XCTAssertEqual(mergedChain.customNodes, Set<ChainNodeModel>())
        XCTAssertNil(mergedChain.selectedNode)
    }

    func testPreservingLocalNodePreferencesDropsRetiredDefaultSelection() throws {
        let remoteChain = makeValidChain(
            generatingAssets: 1,
            addressPrefix: 42
        )
        let retiredNode = ChainNodeModel(
            url: try XCTUnwrap(URL(string: "wss://retired-default.example")),
            name: "Retired default",
            apikey: nil
        )
        let localChain = remoteChain.replacingSelectedNode(retiredNode)

        let mergedChains = ChainSyncService.preservingLocalNodePreferences(
            remoteChains: [remoteChain],
            localChains: [localChain]
        )

        let mergedChain = try XCTUnwrap(mergedChains.first)
        XCTAssertNil(mergedChain.selectedNode)
        XCTAssertFalse(mergedChain.nodes.contains(retiredNode))
    }

    func testPreservingLocalNodePreferencesRefreshesSelectedDefaultByURL() throws {
        let remoteChain = makeValidChain(
            generatingAssets: 1,
            addressPrefix: 42
        )
        let remoteNode = try XCTUnwrap(remoteChain.nodes.first)
        let staleSelectedNode = ChainNodeModel(
            url: remoteNode.url,
            name: "Stale display name",
            apikey: nil
        )
        let localChain = remoteChain.replacingSelectedNode(staleSelectedNode)

        let mergedChains = ChainSyncService.preservingLocalNodePreferences(
            remoteChains: [remoteChain],
            localChains: [localChain]
        )

        XCTAssertEqual(try XCTUnwrap(mergedChains.first).selectedNode, remoteNode)
    }

    func testRepositoryWriteFailureEmitsFailureWithoutFalseCompletion() throws {
        let remoteChain = makeValidChain(
            generatingAssets: 1,
            addressPrefix: 42
        )
        let data = try JSONEncoder().encode([remoteChain])
        let dataFactory = CountingDataOperationFactory(data: data)
        let repository = SaveFailingChainRepository(
            error: ChainSyncCompatibilityTestError.saveFailed
        )
        let eventCenter = RecordingChainSyncEventCenter()
        let failureExpectation = expectation(description: "save failure is propagated")
        let falseCompletionExpectation = expectation(
            description: "failed save never emits completion"
        )
        falseCompletionExpectation.isInverted = true
        eventCenter.onEvent = { event in
            if event is ChainSyncDidFail {
                failureExpectation.fulfill()
            } else if event is ChainSyncDidComplete {
                falseCompletionExpectation.fulfill()
            }
        }
        let service = ChainSyncService(
            chainsUrl: try XCTUnwrap(URL(string: "https://chains.example/chains.json")),
            dataFetchFactory: dataFactory,
            repository: AnyDataProviderRepository(repository),
            eventCenter: eventCenter,
            operationQueue: OperationQueue(),
            retryStrategy: NeverReconnectStrategy(),
            applicationHandler: ApplicationHandler()
        )

        service.syncUp()

        wait(
            for: [failureExpectation, falseCompletionExpectation],
            timeout: 1
        )
        XCTAssertEqual(repository.saveCallCount, 1)
        XCTAssertEqual(dataFactory.fetchCallCount, 0)
        XCTAssertEqual(eventCenter.failureCount, 1)
        XCTAssertEqual(eventCenter.completionCount, 0)
        XCTAssertTrue(
            eventCenter.lastFailure is ChainSyncCompatibilityTestError
        )
    }

    func testRepositoryFetchFailureDoesNotWriteOrReplaceCache() throws {
        let remoteChain = makeValidChain(
            generatingAssets: 1,
            addressPrefix: 42
        )
        let dataFactory = CountingDataOperationFactory(
            data: try JSONEncoder().encode([remoteChain])
        )
        let repository = ScriptedChainRepository(
            fetchAllError: ChainSyncCompatibilityTestError.fetchFailed
        )
        let eventCenter = RecordingChainSyncEventCenter()
        let failureExpectation = expectation(
            description: "database failure is propagated"
        )
        eventCenter.onEvent = { event in
            if event is ChainSyncDidFail {
                failureExpectation.fulfill()
            }
        }
        let service = makeService(
            dataFetchFactory: dataFactory,
            repository: AnyDataProviderRepository(repository),
            eventCenter: eventCenter
        )

        service.syncUp()

        wait(for: [failureExpectation], timeout: 1)
        XCTAssertEqual(repository.replaceCallCount, 0)
        XCTAssertEqual(dataFactory.fetchCallCount, 0)
        XCTAssertEqual(eventCenter.failureCount, 1)
        XCTAssertEqual(eventCenter.completionCount, 0)
    }

    func testEmptyRemotePayloadNeverDeletesReadableCache() throws {
        let repository = ScriptedChainRepository(
            localChains: UniversalWalletRegistry.appOwnedProductionChains
        )
        let eventCenter = RecordingChainSyncEventCenter()
        let failureExpectation = expectation(
            description: "empty authoritative payload is rejected"
        )
        eventCenter.onEvent = { event in
            if event is ChainSyncDidFail {
                failureExpectation.fulfill()
            }
        }
        let service = makeService(
            data: try JSONEncoder().encode([ChainModel]()),
            repository: AnyDataProviderRepository(repository),
            eventCenter: eventCenter
        )

        service.syncUp()

        wait(for: [failureExpectation], timeout: 1)
        XCTAssertEqual(repository.saveCallCount, 0)
        XCTAssertEqual(repository.replaceCallCount, 0)
        XCTAssertNil(eventCenter.lastUpdatedChains)
        XCTAssertEqual(eventCenter.failureCount, 1)
        XCTAssertEqual(eventCenter.completionCount, 0)
        XCTAssertTrue(eventCenter.lastFailure is ChainSyncServiceError)
    }

    func testActiveRemoteChainWithOnlyUnusableNodesPreservesWorkingCache()
        throws {
        let workingChain = makeValidChain(
            generatingAssets: 1,
            addressPrefix: 42
        )
        let unusableNodes: Set<ChainNodeModel> = [
            ChainNodeModel(
                url: try XCTUnwrap(
                    URL(string: "ftp://attacker.example/node")
                ),
                name: "Unsupported scheme",
                apikey: nil
            ),
            ChainNodeModel(
                url: try XCTUnwrap(URL(string: "relative/node")),
                name: "Relative endpoint",
                apikey: nil
            )
        ]
        let hostileRemoteChain = workingChain.replacingNodes(
            unusableNodes
        )
        let repository = ScriptedChainRepository(
            localChains: [workingChain]
        )
        let eventCenter = RecordingChainSyncEventCenter()
        let failureExpectation = expectation(
            description: "an unusable active chain is rejected"
        )
        eventCenter.onEvent = { event in
            if event is ChainSyncDidFail {
                failureExpectation.fulfill()
            }
        }
        let service = makeService(
            data: try JSONEncoder().encode([hostileRemoteChain]),
            repository: AnyDataProviderRepository(repository),
            eventCenter: eventCenter
        )

        service.syncUp()

        wait(for: [failureExpectation], timeout: 1)
        XCTAssertEqual(repository.saveCallCount, 1)
        XCTAssertEqual(repository.replaceCallCount, 0)
        XCTAssertEqual(
            repository.savedModels,
            UniversalWalletRegistry.appOwnedProductionChains
        )
        XCTAssertEqual(
            eventCenter.lastUpdatedChains,
            UniversalWalletRegistry.appOwnedProductionChains
        )
        XCTAssertTrue(repository.deletedIdentifiers.isEmpty)
        XCTAssertEqual(eventCenter.failureCount, 1)
        XCTAssertEqual(eventCenter.completionCount, 0)
    }

    func testMixedRemoteNodesPersistOnlyUsableUniqueEndpoints() throws {
        let baseChain = makeValidChain(
            generatingAssets: 1,
            addressPrefix: 42
        )
        let validNode = try XCTUnwrap(baseChain.nodes.first)
        let duplicateURLNode = ChainNodeModel(
            url: validNode.url,
            name: validNode.name + " duplicate",
            apikey: nil
        )
        let invalidNode = ChainNodeModel(
            url: try XCTUnwrap(URL(string: "file:///tmp/not-a-node")),
            name: "Local file",
            apikey: nil
        )
        let mixedRemoteChain = baseChain.replacingNodes(
            Set([validNode, duplicateURLNode, invalidNode])
        )
        let repository = ScriptedChainRepository()
        let eventCenter = RecordingChainSyncEventCenter()
        let completionExpectation = expectation(
            description: "usable endpoints are saved"
        )
        eventCenter.onEvent = { event in
            if event is ChainSyncDidComplete {
                completionExpectation.fulfill()
            }
        }
        let service = makeService(
            data: try JSONEncoder().encode([mixedRemoteChain]),
            repository: AnyDataProviderRepository(repository),
            eventCenter: eventCenter
        )

        service.syncUp()

        wait(for: [completionExpectation], timeout: 1)
        let savedChain = try XCTUnwrap(repository.savedModels.first)
        XCTAssertEqual(savedChain.nodes.count, 1)
        XCTAssertEqual(savedChain.nodes.first?.url, validNode.url)
        XCTAssertTrue(
            savedChain.nodes.allSatisfy {
                ChainModelMapper.isUsableNodeURL($0.url)
            }
        )
        XCTAssertEqual(eventCenter.failureCount, 0)
        XCTAssertEqual(eventCenter.completionCount, 1)
    }

    func testPartialRemotePayloadDisablesOmittedChainWithoutDeletingPreferences() throws {
        let remoteChains = ChainModelGenerator.generate(count: 2)
        let retainedRemoteChain = remoteChains[0]
        let omittedRemoteChain = remoteChains[1]
        let customNode = ChainNodeModel(
            url: try XCTUnwrap(URL(string: "wss://omitted-user-node.example")),
            name: "Omitted chain preference",
            apikey: nil
        )
        let omittedLocalChain = omittedRemoteChain
            .replacingCustomNodes([customNode])
            .replacingSelectedNode(customNode)
        let repository = ScriptedChainRepository(
            localChains: [retainedRemoteChain, omittedLocalChain]
        )
        let eventCenter = RecordingChainSyncEventCenter()
        let completionExpectation = expectation(
            description: "partial payload is retained non-destructively"
        )
        eventCenter.onEvent = { event in
            if event is ChainSyncDidComplete {
                completionExpectation.fulfill()
            }
        }
        let service = makeService(
            data: try JSONEncoder().encode([retainedRemoteChain]),
            repository: AnyDataProviderRepository(repository),
            eventCenter: eventCenter
        )

        service.syncUp()

        wait(for: [completionExpectation], timeout: 1)
        let disabledChain = try XCTUnwrap(
            repository.savedModels.first {
                $0.chainId == omittedRemoteChain.chainId
            }
        )
        XCTAssertTrue(disabledChain.disabled)
        XCTAssertEqual(disabledChain.customNodes, Set([customNode]))
        XCTAssertEqual(disabledChain.selectedNode, customNode)
        XCTAssertTrue(repository.deletedIdentifiers.isEmpty)
        XCTAssertEqual(eventCenter.failureCount, 0)
    }

    func testReappearingRemoteChainRestoresDisabledPreferences() throws {
        let remoteChain = makeValidChain(
            generatingAssets: 1,
            addressPrefix: 42
        )
        let customNode = ChainNodeModel(
            url: try XCTUnwrap(URL(string: "wss://restored-user-node.example")),
            name: "Restored preference",
            apikey: nil
        )
        let disabledLocalChain = remoteChain
            .replacingCustomNodes([customNode])
            .replacingSelectedNode(customNode)
            .replacingDisabled(true)

        let mergedChains = ChainSyncService.preservingLocalNodePreferences(
            remoteChains: [remoteChain],
            localChains: [disabledLocalChain]
        )

        let restoredChain = try XCTUnwrap(mergedChains.first)
        XCTAssertFalse(restoredChain.disabled)
        XCTAssertEqual(restoredChain.customNodes, Set([customNode]))
        XCTAssertEqual(restoredChain.selectedNode, customNode)
    }

    func testQuarantinedLocalChainDoesNotDiscardHealthyNodePreferences() throws {
        let remoteChain = makeValidChain(
            generatingAssets: 1,
            addressPrefix: 42
        )
        let customNode = ChainNodeModel(
            url: try XCTUnwrap(URL(string: "wss://user-node.example")),
            name: "My private node",
            apikey: nil
        )
        let healthyLocalChain = remoteChain
            .replacingCustomNodes([customNode])
            .replacingSelectedNode(customNode)
        let quarantinedChain = ChainModel(
            rank: nil,
            disabled: true,
            chainId: ChainModelMapper.quarantinedChainIdentifierPrefix + "fixture",
            paraId: nil,
            name: ChainModelMapper.quarantinedChainName,
            xcm: nil,
            nodes: [],
            addressPrefix: 0,
            icon: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
        let repository = ScriptedChainRepository(
            localChains: [healthyLocalChain, quarantinedChain]
        )
        let eventCenter = RecordingChainSyncEventCenter()
        let completionExpectation = expectation(
            description: "healthy preferences survive quarantine cleanup"
        )
        eventCenter.onEvent = { event in
            if event is ChainSyncDidComplete {
                completionExpectation.fulfill()
            }
        }
        let service = makeService(
            data: try JSONEncoder().encode([remoteChain]),
            repository: AnyDataProviderRepository(repository),
            eventCenter: eventCenter
        )

        service.syncUp()

        wait(for: [completionExpectation], timeout: 1)
        XCTAssertEqual(repository.replaceCallCount, 0)
        XCTAssertEqual(repository.saveCallCount, 2)
        XCTAssertEqual(
            repository.savedModels,
            UniversalWalletRegistry.appOwnedProductionChains
        )
        XCTAssertTrue(repository.deletedIdentifiers.isEmpty)
        XCTAssertEqual(eventCenter.failureCount, 0)
        XCTAssertEqual(eventCenter.completionCount, 1)
    }

    func testMalformedChainCleanupFailurePreventsRepositoryMutation() throws {
        let remoteChain = makeValidChain(
            generatingAssets: 1,
            addressPrefix: 42
        )
        let dataFactory = CountingDataOperationFactory(
            data: try JSONEncoder().encode([remoteChain])
        )
        let repository = ScriptedChainRepository()
        let eventCenter = RecordingChainSyncEventCenter()
        let failureExpectation = expectation(
            description: "cleanup failure is propagated before sync"
        )
        eventCenter.onEvent = { event in
            if event is ChainSyncDidFail {
                failureExpectation.fulfill()
            }
        }
        let service = makeService(
            dataFetchFactory: dataFactory,
            repository: AnyDataProviderRepository(repository),
            eventCenter: eventCenter,
            malformedChainCleanupOperationFactory: {
                ClosureOperation {
                    throw ChainSyncCompatibilityTestError.cleanupFailed
                }
            }
        )

        service.syncUp()

        wait(for: [failureExpectation], timeout: 1)
        XCTAssertEqual(repository.saveCallCount, 0)
        XCTAssertEqual(repository.replaceCallCount, 0)
        XCTAssertEqual(dataFactory.fetchCallCount, 0)
        XCTAssertEqual(eventCenter.failureCount, 1)
        XCTAssertEqual(eventCenter.completionCount, 0)
    }

    func testConcurrentSyncRequestsStartSingleDeterministicPipeline()
        throws {
        let remoteChain = makeValidChain(
            generatingAssets: 1,
            addressPrefix: 42
        )
        let expectedChains = try ChainSyncService.sanitizingRemoteChains(
            ChainSyncService.mergingAppOwnedProductionChains(into: [remoteChain])
        )
        let remoteFetchRelease = DispatchSemaphore(value: 0)
        defer { remoteFetchRelease.signal() }
        let remoteFetchStarted = expectation(
            description: "remote fetch starts after app-owned persistence"
        )
        let dataFactory = CountingDataOperationFactory(
            data: try JSONEncoder().encode([remoteChain]),
            firstFetchGate: remoteFetchRelease,
            onFirstFetchStart: remoteFetchStarted.fulfill
        )
        let repository = ScriptedChainRepository()
        let eventCenter = RecordingChainSyncEventCenter()
        let cleanupCounter = LockedCounter()
        let cleanupRelease = DispatchSemaphore(value: 0)
        let cleanupStarted = expectation(
            description: "one cleanup pipeline starts"
        )
        let completion = expectation(
            description: "the reserved pipeline completes"
        )
        eventCenter.onEvent = { event in
            if event is ChainSyncDidComplete {
                completion.fulfill()
            }
        }
        let service = ChainSyncService(
            chainsUrl: try XCTUnwrap(
                URL(string: "https://chains.example/chains.json")
            ),
            dataFetchFactory: dataFactory,
            repository: AnyDataProviderRepository(repository),
            eventCenter: eventCenter,
            operationQueue: OperationQueue(),
            retryStrategy: NeverReconnectStrategy(),
            applicationHandler: ApplicationHandler(),
            malformedChainCleanupOperationFactory: {
                if cleanupCounter.increment() == 1 {
                    cleanupStarted.fulfill()
                }

                return ClosureOperation {
                    cleanupRelease.wait()
                }
            }
        )

        DispatchQueue.concurrentPerform(iterations: 32) { index in
            if index.isMultiple(of: 2) {
                service.syncUp()
            } else {
                service.didReceiveDidBecomeActive(
                    notification: Notification(
                        name: Notification.Name(
                            "ChainSyncConcurrencyRegression"
                        )
                    )
                )
            }
        }

        wait(for: [cleanupStarted], timeout: 1)
        XCTAssertEqual(cleanupCounter.value, 1)
        XCTAssertEqual(eventCenter.startCount, 1)
        XCTAssertEqual(dataFactory.fetchCallCount, 0)
        XCTAssertEqual(repository.fetchAllCallCount, 0)
        XCTAssertEqual(repository.saveCallCount, 0)

        cleanupRelease.signal()
        wait(for: [remoteFetchStarted], timeout: 1)
        XCTAssertEqual(repository.fetchAllCallCount, 1)
        XCTAssertEqual(repository.saveCallCount, 1)
        XCTAssertEqual(
            repository.savedModels,
            UniversalWalletRegistry.appOwnedProductionChains
        )
        XCTAssertEqual(
            eventCenter.lastUpdatedChains,
            UniversalWalletRegistry.appOwnedProductionChains
        )
        XCTAssertEqual(eventCenter.completionCount, 0)

        remoteFetchRelease.signal()
        wait(for: [completion], timeout: 1)

        XCTAssertEqual(cleanupCounter.value, 1)
        XCTAssertEqual(dataFactory.fetchCallCount, 1)
        XCTAssertEqual(repository.fetchAllCallCount, 2)
        XCTAssertEqual(repository.saveCallCount, 2)
        XCTAssertEqual(eventCenter.startCount, 1)
        XCTAssertEqual(eventCenter.failureCount, 0)
        XCTAssertEqual(eventCenter.completionCount, 1)
        XCTAssertEqual(repository.savedModels, expectedChains)
    }

    func testCooldownExpiryDoesNotReleaseBlockedPipeline() throws {
        let remoteChain = makeValidChain(
            generatingAssets: 1,
            addressPrefix: 42
        )
        let expectedChains = try ChainSyncService.sanitizingRemoteChains(
            ChainSyncService.mergingAppOwnedProductionChains(into: [remoteChain])
        )
        let firstFetchRelease = DispatchSemaphore(value: 0)
        let firstFetchStarted = expectation(
            description: "first fetch remains unresolved"
        )
        let dataFactory = CountingDataOperationFactory(
            data: try JSONEncoder().encode([remoteChain]),
            firstFetchGate: firstFetchRelease,
            onFirstFetchStart: {
                firstFetchStarted.fulfill()
            }
        )
        let repository = ScriptedChainRepository()
        let eventCenter = RecordingChainSyncEventCenter()
        let cleanupCounter = LockedCounter()
        let cooldownTimer = ManualCountdownTimer()
        let cooldownTimerQueue = DispatchQueue(
            label: "jp.co.soramitsu.fearless.tests.cooldown.expiry-success"
        )
        let firstCompletion = expectation(
            description: "first pipeline completes"
        )
        let secondCompletion = expectation(
            description: "next pipeline starts after completion"
        )
        eventCenter.onEvent = { event in
            guard event is ChainSyncDidComplete else {
                return
            }

            if eventCenter.completionCount == 1 {
                firstCompletion.fulfill()
            } else if eventCenter.completionCount == 2 {
                secondCompletion.fulfill()
            }
        }
        let service = ChainSyncService(
            chainsUrl: try XCTUnwrap(
                URL(string: "https://chains.example/chains.json")
            ),
            dataFetchFactory: dataFactory,
            repository: AnyDataProviderRepository(repository),
            eventCenter: eventCenter,
            operationQueue: OperationQueue(),
            retryStrategy: NeverReconnectStrategy(),
            applicationHandler: ApplicationHandler(),
            malformedChainCleanupOperationFactory: {
                _ = cleanupCounter.increment()
                return ClosureOperation { () }
            },
            cooldownTimer: cooldownTimer,
            cooldownTimerQueue: cooldownTimerQueue
        )

        service.syncUp()
        wait(for: [firstFetchStarted], timeout: 1)
        drain(cooldownTimerQueue)
        XCTAssertEqual(cooldownTimer.startCount, 1)

        cooldownTimer.expire()

        DispatchQueue.concurrentPerform(iterations: 32) { index in
            if index.isMultiple(of: 2) {
                service.syncUp()
            } else {
                service.didReceiveDidBecomeActive(
                    notification: Notification(
                        name: Notification.Name(
                            "ChainSyncCooldownExpiryRegression"
                        )
                    )
                )
            }
        }

        XCTAssertEqual(cleanupCounter.value, 1)
        XCTAssertEqual(dataFactory.fetchCallCount, 1)
        XCTAssertEqual(repository.fetchAllCallCount, 1)
        XCTAssertEqual(repository.saveCallCount, 1)
        XCTAssertEqual(eventCenter.startCount, 1)
        XCTAssertEqual(eventCenter.completionCount, 0)

        firstFetchRelease.signal()
        wait(for: [firstCompletion], timeout: 1)

        XCTAssertEqual(cleanupCounter.value, 1)
        XCTAssertEqual(dataFactory.fetchCallCount, 1)
        XCTAssertEqual(repository.fetchAllCallCount, 2)
        XCTAssertEqual(repository.saveCallCount, 2)
        XCTAssertEqual(eventCenter.startCount, 1)
        XCTAssertEqual(repository.savedModels, expectedChains)

        service.syncUp()
        wait(for: [secondCompletion], timeout: 1)

        XCTAssertEqual(cleanupCounter.value, 2)
        XCTAssertEqual(dataFactory.fetchCallCount, 2)
        XCTAssertEqual(repository.fetchAllCallCount, 4)
        XCTAssertEqual(repository.saveCallCount, 4)
        XCTAssertEqual(eventCenter.startCount, 2)
        XCTAssertEqual(eventCenter.failureCount, 0)
        XCTAssertEqual(eventCenter.completionCount, 2)
        XCTAssertEqual(repository.savedModels, expectedChains)
    }

    func testSuccessBeforeTimerStartRetainsCooldownUntilExpiry() throws {
        let data = try JSONEncoder().encode([
            makeValidChain(generatingAssets: 1, addressPrefix: 42)
        ])
        let dataFactory = ScriptedDataOperationFactory(
            scripts: [
                { data },
                { data }
            ]
        )
        let repository = ScriptedChainRepository()
        let eventCenter = RecordingChainSyncEventCenter()
        let completionSignal = DispatchSemaphore(value: 0)
        eventCenter.onEvent = { event in
            if event is ChainSyncDidComplete {
                completionSignal.signal()
            }
        }
        let cooldownTimer = ManualCountdownTimer()
        let cooldownTimerQueue = DispatchQueue(
            label: "jp.co.soramitsu.fearless.tests.cooldown.before-success"
        )
        cooldownTimerQueue.suspend()
        var timerQueueIsSuspended = true
        defer {
            if timerQueueIsSuspended {
                cooldownTimerQueue.resume()
            }
        }
        let service = makeService(
            dataFetchFactory: dataFactory,
            repository: AnyDataProviderRepository(repository),
            eventCenter: eventCenter,
            cooldownTimer: cooldownTimer,
            cooldownTimerQueue: cooldownTimerQueue
        )

        service.syncUp()
        waitForSignal(
            completionSignal,
            description: "success before timer start"
        )

        DispatchQueue.concurrentPerform(iterations: 32) { _ in
            service.syncUp()
        }
        XCTAssertEqual(eventCenter.startCount, 1)
        XCTAssertEqual(dataFactory.fetchCallCount, 1)
        XCTAssertEqual(cooldownTimer.startCount, 0)

        cooldownTimerQueue.resume()
        timerQueueIsSuspended = false
        drain(cooldownTimerQueue)
        XCTAssertEqual(cooldownTimer.startCount, 1)

        cooldownTimer.expire()
        service.syncUp()
        waitForSignal(
            completionSignal,
            description: "success after deferred timer expiry"
        )

        XCTAssertEqual(eventCenter.startCount, 2)
        XCTAssertEqual(dataFactory.fetchCallCount, 2)
        XCTAssertEqual(eventCenter.failureCount, 0)
        XCTAssertEqual(eventCenter.completionCount, 2)
    }

    func testSuccessDuringCooldownRemainsBlockedUntilExpiry() throws {
        let data = try JSONEncoder().encode([
            makeValidChain(generatingAssets: 1, addressPrefix: 42)
        ])
        let firstFetchStarted = DispatchSemaphore(value: 0)
        let firstFetchRelease = DispatchSemaphore(value: 0)
        let dataFactory = ScriptedDataOperationFactory(
            scripts: [
                {
                    firstFetchStarted.signal()
                    guard firstFetchRelease.wait(
                        timeout: .now() + 2
                    ) == .success else {
                        throw ChainSyncCompatibilityTestError.gateTimedOut
                    }
                    return data
                },
                { data }
            ]
        )
        let repository = ScriptedChainRepository()
        let eventCenter = RecordingChainSyncEventCenter()
        let completionSignal = DispatchSemaphore(value: 0)
        eventCenter.onEvent = { event in
            if event is ChainSyncDidComplete {
                completionSignal.signal()
            }
        }
        let cooldownTimer = ManualCountdownTimer()
        let cooldownTimerQueue = DispatchQueue(
            label: "jp.co.soramitsu.fearless.tests.cooldown.during-success"
        )
        let service = makeService(
            dataFetchFactory: dataFactory,
            repository: AnyDataProviderRepository(repository),
            eventCenter: eventCenter,
            cooldownTimer: cooldownTimer,
            cooldownTimerQueue: cooldownTimerQueue
        )

        service.syncUp()
        waitForSignal(firstFetchStarted, description: "first gated fetch")
        drain(cooldownTimerQueue)
        XCTAssertEqual(cooldownTimer.startCount, 1)

        firstFetchRelease.signal()
        waitForSignal(
            completionSignal,
            description: "success during cooldown"
        )
        DispatchQueue.concurrentPerform(iterations: 32) { _ in
            service.syncUp()
        }
        XCTAssertEqual(eventCenter.startCount, 1)
        XCTAssertEqual(dataFactory.fetchCallCount, 1)

        cooldownTimer.expire()
        service.syncUp()
        waitForSignal(
            completionSignal,
            description: "success after active cooldown"
        )

        XCTAssertEqual(eventCenter.startCount, 2)
        XCTAssertEqual(dataFactory.fetchCallCount, 2)
        XCTAssertEqual(eventCenter.failureCount, 0)
        XCTAssertEqual(eventCenter.completionCount, 2)
    }

    func testFailureBeforeTimerStartInvalidatesOnlyFailedReservation()
        throws {
        let data = try JSONEncoder().encode([
            makeValidChain(generatingAssets: 1, addressPrefix: 42)
        ])
        let dataFactory = ScriptedDataOperationFactory(
            scripts: [
                {
                    throw ChainSyncCompatibilityTestError.fetchFailed
                },
                { data }
            ]
        )
        let repository = ScriptedChainRepository()
        let eventCenter = RecordingChainSyncEventCenter()
        let failureSignal = DispatchSemaphore(value: 0)
        let completionSignal = DispatchSemaphore(value: 0)
        eventCenter.onEvent = { event in
            if event is ChainSyncDidFail {
                failureSignal.signal()
            } else if event is ChainSyncDidComplete {
                completionSignal.signal()
            }
        }
        let cooldownTimer = ManualCountdownTimer()
        let cooldownTimerQueue = DispatchQueue(
            label: "jp.co.soramitsu.fearless.tests.cooldown.before-failure"
        )
        cooldownTimerQueue.suspend()
        var timerQueueIsSuspended = true
        defer {
            if timerQueueIsSuspended {
                cooldownTimerQueue.resume()
            }
        }
        let service = makeService(
            dataFetchFactory: dataFactory,
            repository: AnyDataProviderRepository(repository),
            eventCenter: eventCenter,
            cooldownTimer: cooldownTimer,
            cooldownTimerQueue: cooldownTimerQueue
        )

        service.syncUp()
        waitForSignal(
            failureSignal,
            description: "failure before timer start"
        )
        XCTAssertEqual(cooldownTimer.startCount, 0)

        DispatchQueue.concurrentPerform(iterations: 32) { _ in
            service.syncUp()
        }
        waitForSignal(
            completionSignal,
            description: "single replacement pipeline"
        )
        XCTAssertEqual(eventCenter.startCount, 2)
        XCTAssertEqual(dataFactory.fetchCallCount, 2)

        cooldownTimerQueue.resume()
        timerQueueIsSuspended = false
        drain(cooldownTimerQueue)

        XCTAssertEqual(
            cooldownTimer.startCount,
            1,
            "the invalidated timer must not start"
        )
        XCTAssertEqual(eventCenter.failureCount, 1)
        XCTAssertEqual(eventCenter.completionCount, 1)
    }

    func testFailureDuringCooldownStopsOldTimerAndAllowsOneReplacement()
        throws {
        let data = try JSONEncoder().encode([
            makeValidChain(generatingAssets: 1, addressPrefix: 42)
        ])
        let firstFetchStarted = DispatchSemaphore(value: 0)
        let firstFetchRelease = DispatchSemaphore(value: 0)
        let dataFactory = ScriptedDataOperationFactory(
            scripts: [
                {
                    firstFetchStarted.signal()
                    guard firstFetchRelease.wait(
                        timeout: .now() + 2
                    ) == .success else {
                        throw ChainSyncCompatibilityTestError.gateTimedOut
                    }
                    throw ChainSyncCompatibilityTestError.fetchFailed
                },
                { data }
            ]
        )
        let repository = ScriptedChainRepository()
        let eventCenter = RecordingChainSyncEventCenter()
        let failureSignal = DispatchSemaphore(value: 0)
        let completionSignal = DispatchSemaphore(value: 0)
        eventCenter.onEvent = { event in
            if event is ChainSyncDidFail {
                failureSignal.signal()
            } else if event is ChainSyncDidComplete {
                completionSignal.signal()
            }
        }
        let cooldownTimer = ManualCountdownTimer()
        let cooldownTimerQueue = DispatchQueue(
            label: "jp.co.soramitsu.fearless.tests.cooldown.during-failure"
        )
        let service = makeService(
            dataFetchFactory: dataFactory,
            repository: AnyDataProviderRepository(repository),
            eventCenter: eventCenter,
            cooldownTimer: cooldownTimer,
            cooldownTimerQueue: cooldownTimerQueue
        )

        service.syncUp()
        waitForSignal(firstFetchStarted, description: "first gated fetch")
        drain(cooldownTimerQueue)
        XCTAssertEqual(cooldownTimer.startCount, 1)

        firstFetchRelease.signal()
        waitForSignal(
            failureSignal,
            description: "failure during cooldown"
        )
        drain(cooldownTimerQueue)
        XCTAssertEqual(cooldownTimer.stopCount, 1)
        if case .stopped = cooldownTimer.state {
            // Expected.
        } else {
            XCTFail("Failed reservation timer must be stopped")
        }

        DispatchQueue.concurrentPerform(iterations: 32) { _ in
            service.syncUp()
        }
        waitForSignal(
            completionSignal,
            description: "replacement after active failure"
        )
        drain(cooldownTimerQueue)

        XCTAssertEqual(eventCenter.startCount, 2)
        XCTAssertEqual(dataFactory.fetchCallCount, 2)
        XCTAssertEqual(cooldownTimer.startCount, 2)
        XCTAssertEqual(eventCenter.failureCount, 1)
        XCTAssertEqual(eventCenter.completionCount, 1)
    }

    func testFailureAfterCooldownExpiryAllowsReplacementWithoutOverlap()
        throws {
        let data = try JSONEncoder().encode([
            makeValidChain(generatingAssets: 1, addressPrefix: 42)
        ])
        let firstFetchStarted = DispatchSemaphore(value: 0)
        let firstFetchRelease = DispatchSemaphore(value: 0)
        let dataFactory = ScriptedDataOperationFactory(
            scripts: [
                {
                    firstFetchStarted.signal()
                    guard firstFetchRelease.wait(
                        timeout: .now() + 2
                    ) == .success else {
                        throw ChainSyncCompatibilityTestError.gateTimedOut
                    }
                    throw ChainSyncCompatibilityTestError.fetchFailed
                },
                { data }
            ]
        )
        let repository = ScriptedChainRepository()
        let eventCenter = RecordingChainSyncEventCenter()
        let failureSignal = DispatchSemaphore(value: 0)
        let completionSignal = DispatchSemaphore(value: 0)
        eventCenter.onEvent = { event in
            if event is ChainSyncDidFail {
                failureSignal.signal()
            } else if event is ChainSyncDidComplete {
                completionSignal.signal()
            }
        }
        let cooldownTimer = ManualCountdownTimer()
        let cooldownTimerQueue = DispatchQueue(
            label: "jp.co.soramitsu.fearless.tests.cooldown.after-failure"
        )
        let service = makeService(
            dataFetchFactory: dataFactory,
            repository: AnyDataProviderRepository(repository),
            eventCenter: eventCenter,
            cooldownTimer: cooldownTimer,
            cooldownTimerQueue: cooldownTimerQueue
        )

        service.syncUp()
        waitForSignal(firstFetchStarted, description: "first gated fetch")
        drain(cooldownTimerQueue)
        cooldownTimer.expire()

        DispatchQueue.concurrentPerform(iterations: 32) { _ in
            service.syncUp()
        }
        XCTAssertEqual(
            eventCenter.startCount,
            1,
            "timer expiry must not release an in-flight pipeline"
        )
        XCTAssertEqual(dataFactory.fetchCallCount, 1)

        firstFetchRelease.signal()
        waitForSignal(
            failureSignal,
            description: "failure after cooldown expiry"
        )
        DispatchQueue.concurrentPerform(iterations: 32) { _ in
            service.syncUp()
        }
        waitForSignal(
            completionSignal,
            description: "replacement after expired failure"
        )

        XCTAssertEqual(eventCenter.startCount, 2)
        XCTAssertEqual(dataFactory.fetchCallCount, 2)
        XCTAssertEqual(eventCenter.failureCount, 1)
        XCTAssertEqual(eventCenter.completionCount, 1)
    }

    func testStaleStopCallbackCannotClearNewerCooldown() throws {
        let data = try JSONEncoder().encode([
            makeValidChain(generatingAssets: 1, addressPrefix: 42)
        ])
        let dataFactory = ScriptedDataOperationFactory(
            scripts: [
                { data },
                { data },
                { data }
            ]
        )
        let repository = ScriptedChainRepository()
        let eventCenter = RecordingChainSyncEventCenter()
        let completionSignal = DispatchSemaphore(value: 0)
        eventCenter.onEvent = { event in
            if event is ChainSyncDidComplete {
                completionSignal.signal()
            }
        }
        let cooldownTimer = ManualCountdownTimer()
        let cooldownTimerQueue = DispatchQueue(
            label: "jp.co.soramitsu.fearless.tests.cooldown.stale-stop"
        )
        let service = makeService(
            dataFetchFactory: dataFactory,
            repository: AnyDataProviderRepository(repository),
            eventCenter: eventCenter,
            cooldownTimer: cooldownTimer,
            cooldownTimerQueue: cooldownTimerQueue
        )

        service.syncUp()
        waitForSignal(completionSignal, description: "first success")
        drain(cooldownTimerQueue)
        cooldownTimer.expire()

        service.syncUp()
        waitForSignal(completionSignal, description: "second success")
        drain(cooldownTimerQueue)
        XCTAssertEqual(cooldownTimer.startCount, 2)

        cooldownTimer.emitStaleStopWhileRunning()
        DispatchQueue.concurrentPerform(iterations: 32) { _ in
            service.syncUp()
        }
        XCTAssertEqual(
            eventCenter.startCount,
            2,
            "a stale callback must not clear the current cooldown"
        )
        XCTAssertEqual(dataFactory.fetchCallCount, 2)

        cooldownTimer.expire()
        DispatchQueue.concurrentPerform(iterations: 32) { _ in
            service.syncUp()
        }
        waitForSignal(
            completionSignal,
            description: "third success after real expiry"
        )

        XCTAssertEqual(eventCenter.startCount, 3)
        XCTAssertEqual(dataFactory.fetchCallCount, 3)
        XCTAssertEqual(eventCenter.failureCount, 0)
        XCTAssertEqual(eventCenter.completionCount, 3)
    }

    func testSanitizerRejectsDuplicateRemoteIdentifiers() {
        let chain = makeValidChain(
            generatingAssets: 1,
            addressPrefix: 42
        )

        XCTAssertThrowsError(
            try ChainSyncService.sanitizingRemoteChains([chain, chain])
        ) { error in
            guard
                let syncError = error as? ChainSyncServiceError,
                case let .duplicateRemoteChainIdentifier(identifier) =
                    syncError
            else {
                return XCTFail("Unexpected error: \(error)")
            }

            XCTAssertEqual(identifier, chain.chainId)
        }
    }

    func testSanitizerRejectsBlankNoncanonicalAndReservedIdentifiers() {
        let chain = makeValidChain(
            generatingAssets: 1,
            addressPrefix: 42
        )
        let invalidIdentifiers = [
            "",
            " \n",
            " leading-space",
            "trailing-space ",
            ChainModelMapper.quarantinedChainIdentifierPrefix + "remote"
        ]

        for identifier in invalidIdentifiers {
            let invalidChain = copy(
                chain,
                chainId: identifier
            )

            XCTAssertThrowsError(
                try ChainSyncService.sanitizingRemoteChains(
                    [invalidChain]
                ),
                "identifier \(identifier.debugDescription) must fail"
            )
        }
    }

    func testSanitizerRejectsBlankRemoteName() {
        let chain = makeValidChain(
            generatingAssets: 1,
            addressPrefix: 42
        )
        let invalidChain = copy(chain, name: " \n\t")

        XCTAssertThrowsError(
            try ChainSyncService.sanitizingRemoteChains([invalidChain])
        )
    }

    func testSanitizerAllowsDisabledChainWithoutNodes() throws {
        let chain = makeValidChain(
            generatingAssets: 1,
            addressPrefix: 42
        )
        let disabledChain = copy(
            chain,
            disabled: true,
            nodes: []
        )

        let sanitized = try ChainSyncService.sanitizingRemoteChains(
            [disabledChain]
        )

        XCTAssertEqual(sanitized.count, 1)
        XCTAssertTrue(try XCTUnwrap(sanitized.first).disabled)
        XCTAssertTrue(try XCTUnwrap(sanitized.first).nodes.isEmpty)
    }

    func testSanitizerDeterministicallyDeduplicatesNodeCredentialMetadata()
        throws {
        let chain = makeValidChain(
            generatingAssets: 1,
            addressPrefix: 42
        )
        let url = try XCTUnwrap(URL(string: "wss://same-node.example"))
        let expectedAPIKey = ChainNodeModel.ApiKey(
            queryName: "a-query",
            keyName: "a-key"
        )
        let nodes: Set<ChainNodeModel> = [
            ChainNodeModel(
                url: url,
                name: "Same Node",
                apikey: .init(
                    queryName: "z-query",
                    keyName: "z-key"
                )
            ),
            ChainNodeModel(
                url: url,
                name: "Same Node",
                apikey: expectedAPIKey
            )
        ]

        for _ in 0 ..< 10 {
            let sanitized = try ChainSyncService
                .sanitizingRemoteChains([
                    copy(chain, nodes: nodes)
                ])
            let node = try XCTUnwrap(
                sanitized.first?.nodes.first
            )

            XCTAssertEqual(node.apikey, expectedAPIKey)
        }
    }

    func testSanitizerRejectsEthereumChainWithOnlyIncompatibleSchemes()
        throws {
        let baseChain = makeValidChain(
            generatingAssets: 1,
            addressPrefix: 42
        )
        let insecureNodes: Set<ChainNodeModel> = [
            ChainNodeModel(
                url: try XCTUnwrap(
                    URL(string: "http://rpc.example")
                ),
                name: "HTTP",
                apikey: nil
            ),
            ChainNodeModel(
                url: try XCTUnwrap(URL(string: "ws://rpc.example")),
                name: "WS",
                apikey: nil
            )
        ]
        let ethereumChain = copy(
            baseChain,
            nodes: insecureNodes,
            options: [.ethereum]
        )

        XCTAssertThrowsError(
            try ChainSyncService.sanitizingRemoteChains(
                [ethereumChain]
            )
        )
    }

    func testSanitizerKeepsOnlyRuntimeCompatibleEthereumNodes() throws {
        let baseChain = makeValidChain(
            generatingAssets: 1,
            addressPrefix: 42
        )
        let httpsNode = ChainNodeModel(
            url: try XCTUnwrap(URL(string: "https://rpc.example")),
            name: "HTTPS",
            apikey: nil
        )
        let httpNode = ChainNodeModel(
            url: try XCTUnwrap(URL(string: "http://rpc.example")),
            name: "HTTP",
            apikey: nil
        )
        let ethereumChain = copy(
            baseChain,
            nodes: [httpsNode, httpNode],
            options: [.ethereum]
        )

        let sanitized = try ChainSyncService.sanitizingRemoteChains(
            [ethereumChain]
        )

        XCTAssertEqual(
            try XCTUnwrap(sanitized.first).nodes,
            Set([httpsNode])
        )
    }

    func testPreservingPreferencesDropsRuntimeIncompatibleCustomSelection()
        throws {
        let substrateRemote = makeValidChain(
            generatingAssets: 1,
            addressPrefix: 42
        )
        let incompatibleSubstrateNode = ChainNodeModel(
            url: try XCTUnwrap(
                URL(string: "https://not-a-websocket.example")
            ),
            name: "Wrong protocol",
            apikey: nil
        )
        let substrateLocal = substrateRemote
            .replacingCustomNodes([incompatibleSubstrateNode])
            .replacingSelectedNode(incompatibleSubstrateNode)

        let merged = ChainSyncService.preservingLocalNodePreferences(
            remoteChains: [substrateRemote],
            localChains: [substrateLocal]
        )

        XCTAssertEqual(
            try XCTUnwrap(merged.first).customNodes,
            Set<ChainNodeModel>()
        )
        XCTAssertNil(try XCTUnwrap(merged.first).selectedNode)
    }

    func testSanitizerStripsRemotePreferencesForBrandNewChain() throws {
        let chain = makeValidChain(
            generatingAssets: 1,
            addressPrefix: 42
        )
        let injectedNode = ChainNodeModel(
            url: try XCTUnwrap(
                URL(string: "wss://remote-injection.example")
            ),
            name: "Injected",
            apikey: nil
        )
        let injectedChain = chain
            .replacingCustomNodes([injectedNode])
            .replacingSelectedNode(injectedNode)

        let sanitized = try ChainSyncService.sanitizingRemoteChains(
            [injectedChain]
        )

        XCTAssertEqual(
            try XCTUnwrap(sanitized.first).customNodes,
            Set<ChainNodeModel>()
        )
        XCTAssertNil(try XCTUnwrap(sanitized.first).selectedNode)
    }

    private func copy(
        _ chain: ChainModel,
        chainId: String? = nil,
        name: String? = nil,
        disabled: Bool? = nil,
        nodes: Set<ChainNodeModel>? = nil,
        options: [ChainOptions]? = nil,
        assets: Set<AssetModel>? = nil
    ) -> ChainModel {
        ChainModel(
            rank: chain.rank,
            disabled: disabled ?? chain.disabled,
            chainId: chainId ?? chain.chainId,
            parentId: chain.parentId,
            paraId: chain.paraId,
            name: name ?? chain.name,
            assets: assets ?? chain.assets,
            xcm: chain.xcm,
            nodes: nodes ?? chain.nodes,
            addressPrefix: chain.addressPrefix,
            types: chain.types,
            icon: chain.icon,
            options: options ?? chain.options,
            externalApi: chain.externalApi,
            selectedNode: nil,
            customNodes: nil,
            iosMinAppVersion: chain.iosMinAppVersion,
            identityChain: chain.identityChain
        )
    }

    private func makeValidChain(
        generatingAssets count: Int,
        addressPrefix: UInt16
    ) -> ChainModel {
        let chain = ChainModelGenerator.generateChain(
            generatingAssets: count,
            addressPrefix: addressPrefix
        )
        let node = ChainNodeModel(
            url: URL(
                string: "wss://node.example/\(chain.chainId)"
            )!,
            name: "Valid substrate node",
            apikey: nil
        )

        return chain.replacingNodes([node])
    }

    private func makeService(
        data: Data,
        repository: AnyDataProviderRepository<ChainModel>,
        eventCenter: EventCenterProtocol,
        malformedChainCleanupOperationFactory: (() -> BaseOperation<Void>)? = nil
    ) -> ChainSyncService {
        makeService(
            dataFetchFactory: StaticDataOperationFactory(data: data),
            repository: repository,
            eventCenter: eventCenter,
            malformedChainCleanupOperationFactory:
                malformedChainCleanupOperationFactory
        )
    }

    private func makeService(
        dataFetchFactory: DataOperationFactoryProtocol,
        repository: AnyDataProviderRepository<ChainModel>,
        eventCenter: EventCenterProtocol,
        malformedChainCleanupOperationFactory: (() -> BaseOperation<Void>)? = nil,
        cooldownTimer: CountdownTimerProtocol = CountdownTimer(
            notificationInterval: 300
        ),
        cooldownTimerQueue: DispatchQueue = .main
    ) -> ChainSyncService {
        ChainSyncService(
            chainsUrl: URL(string: "https://chains.example/chains.json")!,
            dataFetchFactory: dataFetchFactory,
            repository: repository,
            eventCenter: eventCenter,
            operationQueue: OperationQueue(),
            retryStrategy: NeverReconnectStrategy(),
            applicationHandler: ApplicationHandler(),
            malformedChainCleanupOperationFactory:
                malformedChainCleanupOperationFactory,
            cooldownTimer: cooldownTimer,
            cooldownTimerQueue: cooldownTimerQueue
        )
    }

    private func waitForSignal(
        _ semaphore: DispatchSemaphore,
        description: String,
        timeout: TimeInterval = 2,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard semaphore.wait(
            timeout: .now() + timeout
        ) == .success else {
            return XCTFail(
                "Timed out waiting for \(description)",
                file: file,
                line: line
            )
        }
    }

    private func drain(
        _ queue: DispatchQueue,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let drained = DispatchSemaphore(value: 0)
        queue.async {
            drained.signal()
        }
        waitForSignal(
            drained,
            description: "serial cooldown timer queue",
            file: file,
            line: line
        )
    }
}

private enum ChainSyncCompatibilityTestError: Error {
    case fetchFailed
    case saveFailed
    case cleanupFailed
    case gateTimedOut
    case unexpectedFetch
}

private struct StaticDataOperationFactory: DataOperationFactoryProtocol {
    let data: Data

    func fetchData(from _: URL) -> BaseOperation<Data> {
        ClosureOperation { data }
    }
}

private final class CountingDataOperationFactory:
    DataOperationFactoryProtocol {
    private let lock = NSLock()
    private let data: Data
    private let firstFetchGate: DispatchSemaphore?
    private let onFirstFetchStart: (() -> Void)?
    private var fetchCalls = 0

    var fetchCallCount: Int {
        lock.with { fetchCalls }
    }

    init(
        data: Data,
        firstFetchGate: DispatchSemaphore? = nil,
        onFirstFetchStart: (() -> Void)? = nil
    ) {
        self.data = data
        self.firstFetchGate = firstFetchGate
        self.onFirstFetchStart = onFirstFetchStart
    }

    func fetchData(from _: URL) -> BaseOperation<Data> {
        let callIndex = lock.with {
            fetchCalls += 1
            return fetchCalls
        }

        return ClosureOperation {
            if callIndex == 1, let firstFetchGate = self.firstFetchGate {
                self.onFirstFetchStart?()
                firstFetchGate.wait()
            }

            return self.data
        }
    }
}

private final class ScriptedDataOperationFactory:
    DataOperationFactoryProtocol {
    typealias FetchScript = () throws -> Data

    private let lock = NSLock()
    private let scripts: [FetchScript]
    private var fetchCalls = 0

    var fetchCallCount: Int {
        lock.with { fetchCalls }
    }

    init(scripts: [FetchScript]) {
        self.scripts = scripts
    }

    func fetchData(from _: URL) -> BaseOperation<Data> {
        let script: FetchScript = lock.with {
            let index = fetchCalls
            fetchCalls += 1

            guard scripts.indices.contains(index) else {
                return {
                    throw ChainSyncCompatibilityTestError.unexpectedFetch
                }
            }

            return scripts[index]
        }

        return ClosureOperation {
            try script()
        }
    }
}

private final class ManualCountdownTimer: CountdownTimerProtocol {
    weak var delegate: CountdownTimerDelegate?

    private let lock = NSLock()
    private var currentState: CountdownTimerState = .stopped
    private var currentRemainedInterval: TimeInterval = 0
    private var starts = 0
    private var stops = 0

    let notificationInterval: TimeInterval

    var state: CountdownTimerState {
        lock.with { currentState }
    }

    var remainedInterval: TimeInterval {
        lock.with { currentRemainedInterval }
    }

    var startCount: Int {
        lock.with { starts }
    }

    var stopCount: Int {
        lock.with { stops }
    }

    init(notificationInterval: TimeInterval = 300) {
        self.notificationInterval = notificationInterval
    }

    func start(
        with interval: TimeInterval,
        runLoop _: RunLoop,
        mode _: RunLoop.Mode
    ) {
        stop()

        lock.with {
            currentState = .inProgress
            currentRemainedInterval = interval
            starts += 1
        }
        delegate?.didStart(with: interval)
    }

    func stop() {
        let stoppedInterval: TimeInterval? = lock.with {
            switch currentState {
            case .inProgress, .paused:
                let interval = currentRemainedInterval
                currentState = .stopped
                currentRemainedInterval = 0
                stops += 1
                return interval
            case .stopped:
                return nil
            }
        }

        if let stoppedInterval {
            delegate?.didStop(with: stoppedInterval)
        }
    }

    func expire() {
        let shouldNotify = lock.with {
            guard case .inProgress = currentState else {
                return false
            }

            currentState = .stopped
            currentRemainedInterval = 0
            stops += 1
            return true
        }

        if shouldNotify {
            delegate?.didStop(with: 0)
        }
    }

    func emitStaleStopWhileRunning() {
        let interval = remainedInterval
        delegate?.didStop(with: interval)
    }
}

private final class LockedCounter {
    private let lock = NSLock()
    private var count = 0

    var value: Int {
        lock.with { count }
    }

    func increment() -> Int {
        lock.with {
            count += 1
            return count
        }
    }
}

private struct NeverReconnectStrategy: ReconnectionStrategyProtocol {
    func reconnectAfter(attempt _: Int) -> TimeInterval? {
        nil
    }
}

private final class RecordingChainSyncEventCenter: EventCenterProtocol {
    private let lock = NSLock()
    private var failures: [Error] = []
    private var completions = 0
    private var starts = 0
    private var updatedChains: [[ChainModel]] = []

    var onEvent: ((EventProtocol) -> Void)?

    var failureCount: Int {
        lock.with { failures.count }
    }

    var completionCount: Int {
        lock.with { completions }
    }

    var startCount: Int {
        lock.with { starts }
    }

    var lastFailure: Error? {
        lock.with { failures.last }
    }

    var lastUpdatedChains: [ChainModel]? {
        lock.with { updatedChains.last }
    }

    func notify(with event: EventProtocol) {
        lock.with {
            if event is ChainSyncDidStart {
                starts += 1
            } else if let failure = event as? ChainSyncDidFail {
                failures.append(failure.error)
            } else if event is ChainSyncDidComplete {
                completions += 1
            } else if let update = event as? ChainsUpdatedEvent {
                updatedChains.append(update.updatedChains)
            }
        }

        onEvent?(event)
    }

    func add(observer _: EventVisitorProtocol, dispatchIn _: DispatchQueue?) {}

    func remove(observer _: EventVisitorProtocol) {}
}

private final class SaveFailingChainRepository: DataProviderRepositoryProtocol {
    typealias Model = ChainModel

    private let lock = NSLock()
    private let error: Error
    private var saves = 0

    var saveCallCount: Int {
        lock.with { saves }
    }

    init(error: Error) {
        self.error = error
    }

    func fetchOperation(
        by _: @escaping () throws -> [String],
        options _: RepositoryFetchOptions
    ) -> BaseOperation<[ChainModel]> {
        ClosureOperation { [] }
    }

    func fetchOperation(
        by _: @escaping () throws -> String,
        options _: RepositoryFetchOptions
    ) -> BaseOperation<ChainModel?> {
        ClosureOperation { nil }
    }

    func fetchAllOperation(
        with _: RepositoryFetchOptions
    ) -> BaseOperation<[ChainModel]> {
        ClosureOperation { [] }
    }

    func fetchOperation(
        by _: RepositorySliceRequest,
        options _: RepositoryFetchOptions
    ) -> BaseOperation<[ChainModel]> {
        ClosureOperation { [] }
    }

    func saveOperation(
        _: @escaping () throws -> [ChainModel],
        _: @escaping () throws -> [String]
    ) -> BaseOperation<Void> {
        lock.with {
            saves += 1
        }

        return ClosureOperation { [error] in
            throw error
        }
    }

    func saveBatchOperation(
        _ updateModelsBlock: @escaping () throws -> [ChainModel],
        _ deleteIdsBlock: @escaping () throws -> [String]
    ) -> BaseOperation<Void> {
        saveOperation(updateModelsBlock, deleteIdsBlock)
    }

    func replaceOperation(
        _: @escaping () throws -> [ChainModel]
    ) -> BaseOperation<Void> {
        ClosureOperation { [error] in
            throw error
        }
    }

    func fetchCountOperation() -> BaseOperation<Int> {
        ClosureOperation { 0 }
    }

    func deleteAllOperation() -> BaseOperation<Void> {
        ClosureOperation { () }
    }
}

private final class ScriptedChainRepository: DataProviderRepositoryProtocol {
    typealias Model = ChainModel

    private let lock = NSLock()
    private let fetchAllError: Error?
    private let localChains: [ChainModel]
    private var fetchAllCalls = 0
    private var replaceCalls = 0
    private var saveCalls = 0
    private var saved: [ChainModel] = []
    private var deleted: [String] = []

    var replaceCallCount: Int {
        lock.with { replaceCalls }
    }

    var fetchAllCallCount: Int {
        lock.with { fetchAllCalls }
    }

    var saveCallCount: Int {
        lock.with { saveCalls }
    }

    var savedModels: [ChainModel] {
        lock.with { saved }
    }

    var deletedIdentifiers: [String] {
        lock.with { deleted }
    }

    init(
        fetchAllError: Error? = nil,
        localChains: [ChainModel] = []
    ) {
        self.fetchAllError = fetchAllError
        self.localChains = localChains
    }

    func fetchOperation(
        by _: @escaping () throws -> [String],
        options _: RepositoryFetchOptions
    ) -> BaseOperation<[ChainModel]> {
        ClosureOperation { [] }
    }

    func fetchOperation(
        by _: @escaping () throws -> String,
        options _: RepositoryFetchOptions
    ) -> BaseOperation<ChainModel?> {
        ClosureOperation { nil }
    }

    func fetchAllOperation(
        with _: RepositoryFetchOptions
    ) -> BaseOperation<[ChainModel]> {
        lock.with {
            fetchAllCalls += 1
        }

        return ClosureOperation { [fetchAllError] in
            if let fetchAllError {
                throw fetchAllError
            }

            return self.localChains
        }
    }

    func fetchOperation(
        by _: RepositorySliceRequest,
        options _: RepositoryFetchOptions
    ) -> BaseOperation<[ChainModel]> {
        ClosureOperation { [] }
    }

    func saveOperation(
        _ updateModelsBlock: @escaping () throws -> [ChainModel],
        _ deleteIdsBlock: @escaping () throws -> [String]
    ) -> BaseOperation<Void> {
        ClosureOperation { [weak self] in
            guard let self else {
                throw BaseOperationError.parentOperationCancelled
            }

            let models = try updateModelsBlock()
            let identifiers = try deleteIdsBlock()
            lock.with {
                self.saveCalls += 1
                self.saved = models
                self.deleted = identifiers
            }
        }
    }

    func saveBatchOperation(
        _: @escaping () throws -> [ChainModel],
        _: @escaping () throws -> [String]
    ) -> BaseOperation<Void> {
        ClosureOperation { () }
    }

    func replaceOperation(
        _ modelsBlock: @escaping () throws -> [ChainModel]
    ) -> BaseOperation<Void> {
        ClosureOperation { [weak self] in
            guard let self else {
                throw BaseOperationError.parentOperationCancelled
            }

            _ = try modelsBlock()
            lock.with {
                self.replaceCalls += 1
            }
        }
    }

    func fetchCountOperation() -> BaseOperation<Int> {
        ClosureOperation { 0 }
    }

    func deleteAllOperation() -> BaseOperation<Void> {
        ClosureOperation { () }
    }
}
