import XCTest
@testable import fearless
import FearlessUtils
import IrohaCrypto
import RobinHood
import BigInt

class StakingTests: XCTestCase {
    let logger: LoggerProtocol = {
        let shared = Logger.shared
        shared.minLevel = .debug
        return shared
    }()

    func testNominationsFetch() throws {
        // given

        let address = "5CDayXd3cDCWpBkSXVsVfhE5bWKyTZdD3D1XUinR1ezS1sGn"
        let ss58Factory = SS58AddressFactory()
        let accountId = try ss58Factory.accountId(fromAddress: address, type: .genericSubstrate)

        let url = URL(string: "wss://westend-rpc.polkadot.io/")!
        let operationQueue = OperationQueue()


        let engine = WebSocketEngine(url: url, logger: logger)

        // when

        let key = try StorageKeyFactory().nominators(accountId).toHex(includePrefix: true)
        let operation = JSONRPCListOperation<JSONScaleDecodable<Nominations>>(engine: engine,
                                                     method: RPCMethod.getStorage,
                                                     parameters: [key])
        operationQueue.addOperations([operation], waitUntilFinished: true)

        // then

        do {
            let result = try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            guard let nominations = result.underlyingValue else {
                logger.debug("No nominations found")
                return
            }

            let validators = try nominations.targets.map { accountId in
                try ss58Factory.address(fromPublicKey: AccountIdWrapper(rawData: accountId.value),
                                        type: .genericSubstrate)
            }

            logger.debug("Validators: " + "\(validators)")
            logger.debug("Submitted in: " + "\(nominations.submittedInEra)")
            logger.debug("Suppressed: " + "\(nominations.suppressed)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFetchValidators() throws {
        // given

        let ss58Factory = SS58AddressFactory()

        let url = URL(string: "wss://westend-rpc.polkadot.io/")!
        let operationQueue = OperationQueue()

        let engine = WebSocketEngine(url: url, logger: logger)

        // when

        let key = try StorageKeyFactory().validators().toHex(includePrefix: true)
        let operation = JSONRPCListOperation<JSONScaleDecodable<[AccountId]>>(engine: engine,
                                                     method: RPCMethod.getStorage,
                                                     parameters: [key])
        operationQueue.addOperations([operation], waitUntilFinished: true)

        // then

        do {
            let result = try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            guard let validators = result.underlyingValue else {
                logger.debug("No nominations found")
                return
            }

            let addresses = try validators.map { accountId in
                try ss58Factory.address(fromPublicKey: AccountIdWrapper(rawData: accountId.value),
                                        type: .genericSubstrate)
            }

            logger.debug("All validators: " + "\(addresses)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFetchEraStakers() throws {
        // given

        let ss58Factory = SS58AddressFactory()

        let url = URL(string: "wss://westend-rpc.polkadot.io/")!
        let operationQueue = OperationQueue()

        let engine = WebSocketEngine(url: url, logger: logger)

        // when

        let storageKeyFactory = StorageKeyFactory()

        let currentEraKey = try storageKeyFactory.currentEra().toHex(includePrefix: true)
        let currentEraOperation = JSONRPCListOperation<JSONScaleDecodable<UInt32>>(engine: engine,
                                                                                   method: RPCMethod.getStorage,
                                                                                   parameters: [currentEraKey])

        let stakersOperation = JSONRPCOperation<PagedKeysRequest, [String]>(engine: engine,
                                                                            method: RPCMethod.getStorageKeysPaged,
                                                                            timeout: 60)
        stakersOperation.configurationBlock = {
            guard let currentEra = try? currentEraOperation.extractResultData()?.underlyingValue else {
                stakersOperation.cancel()
                return
            }

            guard let key = try? storageKeyFactory
                    .eraStakers(for: currentEra).toHex(includePrefix: true) else {
                stakersOperation.cancel()
                return
            }

            stakersOperation.parameters = PagedKeysRequest(key: key, count: 1000, offset: nil)
        }

        stakersOperation.addDependency(currentEraOperation)

        operationQueue.addOperations([currentEraOperation, stakersOperation],
                                     waitUntilFinished: true)

        // then

        do {
            guard let keys = try stakersOperation.extractResultData() else {
                logger.debug("No keys")
                return
            }

            let addresses: [String] = try keys.map { key in
                let accountId = try Data(hexString: key).suffix(32)
                return try ss58Factory.address(fromPublicKey: AccountIdWrapper(rawData: accountId),
                                               type: .genericSubstrate)
            }

            logger.debug("Validators: \(addresses)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFetchWannabeValidators() throws {
        // given

        let ss58Factory = SS58AddressFactory()

        let url = URL(string: "wss://rpc.polkadot.io")!
        let operationQueue = OperationQueue()

        let engine = WebSocketEngine(url: url, logger: logger)

        // when

        let key = try StorageKeyFactory().wannabeValidators().toHex(includePrefix: true)

        let params = PagedKeysRequest(key: key, count: 1000, offset: nil)
        let operation = JSONRPCOperation<PagedKeysRequest, [String]>(engine: engine,
                                                       method: RPCMethod.getStorageKeysPaged,
                                                       parameters: params,
                                                       timeout: 60)

        operationQueue.addOperations([operation], waitUntilFinished: true)

        // then

        do {
            guard let keys = try operation.extractResultData() else {
                logger.debug("No keys")
                return
            }

            let addresses: [String] = try keys.map { key in
                let accountId = try Data(hexString: key).suffix(32)
                return try ss58Factory.address(fromPublicKey: AccountIdWrapper(rawData: accountId),
                                               type: .genericSubstrate)
            }

            logger.debug("Wannabe Validators: \(addresses)")
            logger.debug("Wannabe Validators count: \(addresses.count)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testHistoryDepth() throws {
        // given

        let url = URL(string: "wss://polkadot.elara.patract.io/")!

        let operationQueue = OperationQueue()

        let engine = WebSocketEngine(url: url, logger: logger)

        let storageKeyFactory = StorageKeyFactory()

        let historyDepthKey = try storageKeyFactory.historyDepth().toHex(includePrefix: true)

        let operation = JSONRPCListOperation<JSONScaleDecodable<UInt32>>(engine: engine,
                                                                         method: RPCMethod.getStorage,
                                                                         parameters: [historyDepthKey])

        operationQueue.addOperations([operation], waitUntilFinished: true)

        if let depth = try operation
            .extractResultData(throwing: BaseOperationError.parentOperationCancelled).underlyingValue {
            logger.info("History depth: \(depth)")
        } else {
            logger.info("Empty history depth")
        }
    }

    func testFetchOverview() throws {
        // given

        let url = URL(string: "wss://kusama-rpc.polkadot.io/")!

        let operationQueue = OperationQueue()

        let engine = WebSocketEngine(url: url, logger: logger)

        // when

        let storageKeyFactory = StorageKeyFactory()
        let activeEraKey = try storageKeyFactory.activeEra().toHex(includePrefix: true)
        let currentEraKey = try storageKeyFactory.currentEra().toHex(includePrefix: true)
        let sessionIndexKey = try storageKeyFactory.sessionIndex().toHex(includePrefix: true)
        let validatorsCountKey = try storageKeyFactory
            .stakingValidatorsCount().toHex(includePrefix: true)
        let totalIssuanceKey = try storageKeyFactory.totalIssuance().toHex(includePrefix: true)
        let historyDepthKey = try storageKeyFactory.historyDepth().toHex(includePrefix: true)

        let allKeys = [
            activeEraKey,
            currentEraKey,
            sessionIndexKey,
            validatorsCountKey,
            historyDepthKey,
            totalIssuanceKey
        ]

        let operation = JSONRPCOperation<[[String]], [StorageUpdate]>(engine: engine,
                                                                    method: RPCMethod.queryStorageAt,
                                                                    parameters: [allKeys])

        operationQueue.addOperations([operation], waitUntilFinished: true)

        // then

        do {
            guard let result = try operation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                    .first else {
                logger.error("No result found")
                return
            }

            let storageData = StorageUpdateData(update: result)

            if let activeEraData  = storageData.changes
                    .first(where:{ $0.key.toHex(includePrefix: true) == activeEraKey})?.value {
                let scaleDecoder = try ScaleDecoder(data: activeEraData)
                let activeEra = try UInt32(scaleDecoder: scaleDecoder)
                logger.info("Active era: \(activeEra)")
            } else {
                logger.info("Empty active era")
            }

            if let currentEraData  = storageData.changes
                    .first(where:{ $0.key.toHex(includePrefix: true) == currentEraKey})?.value {
                let scaleDecoder = try ScaleDecoder(data: currentEraData)
                let currentEra = try UInt32(scaleDecoder: scaleDecoder)
                logger.info("Current era: \(currentEra)")
            } else {
                logger.info("Empty current era")
            }

            if let sessionIndexData  = storageData.changes
                    .first(where:{ $0.key.toHex(includePrefix: true) == sessionIndexKey})?.value {
                let scaleDecoder = try ScaleDecoder(data: sessionIndexData)
                let sessionIndex = try UInt32(scaleDecoder: scaleDecoder)
                logger.info("Session index: \(sessionIndex)")
            } else {
                logger.info("Empty session index")
            }

            if let validatorCountData  = storageData.changes
                    .first(where:{ $0.key.toHex(includePrefix: true) == validatorsCountKey})?.value {
                let scaleDecoder = try ScaleDecoder(data: validatorCountData)
                let validatorCount = try UInt32(scaleDecoder: scaleDecoder)
                logger.info("Validator count: \(validatorCount)")
            } else {
                logger.info("Empty validator count")
            }

            if let historyDepthData = storageData.changes
                .first(where: { $0.key.toHex(includePrefix: true) == historyDepthKey})?.value {
                let scaleDecoder = try ScaleDecoder(data: historyDepthData)
                let historyDepth = try UInt32(scaleDecoder: scaleDecoder)
                logger.info("History depth: \(historyDepth)")
            } else {
                logger.info("Empty history depth")
            }

            if let totalIssuanceData = storageData.changes
                .first(where: { $0.key.toHex(includePrefix: true) == totalIssuanceKey })?.value {
                let scaleDecoder = try ScaleDecoder(data: totalIssuanceData)
                let balance = try Balance(scaleDecoder: scaleDecoder)
                logger.info("Total issuance \(balance.value)")
            } else {
                logger.info("Empty total issuance")
            }

        } catch {
            logger.debug("Unexpected error: \(error)")
        }
    }

    func testRecommendationsMeasuring() throws {
        self.measure {
            do {
                let url = URL(string: "wss://kusama-rpc.polkadot.io/")!
                try performRecommendations(for: url)
            } catch {
                logger.error("Unexpected error: \(error)")
            }
        }
    }

    func testSlashingSpansMeasuring() throws {
        self.measure {
            do {
                let url = URL(string: "wss://kusama-rpc.polkadot.io/")!
                try performSlashingSpans(url: url)
            } catch {
                logger.error("Unexpected error: \(error)")
            }
        }
    }

    // MARK: Private

    func performNominationState(url: URL) throws {
        // given

        let engine = WebSocketEngine(url: url, logger: logger)
        let storageFactory = StorageKeyFactory()
        let operationQueue = OperationQueue()
    }

    func performSlashingSpans(url: URL) throws {
        // given

        let engine = WebSocketEngine(url: url, logger: logger)
        let storageFactory = StorageKeyFactory()
        let operationQueue = OperationQueue()

        // when

        let slashedPartialKey = try storageFactory.slashedAccounts().toHex(includePrefix: true)
        let slashedAccountIds = try fetchAccountIds(for: slashedPartialKey,
                                                    engine: engine, itemsPerPage: 1000,
                                                    operationQueue: operationQueue)

        // then

        logger.debug("Total slashed accounts: \(slashedAccountIds.count)")

        let allSlashings: [Data: SlashingSpans] = try fetchItems(for: slashedAccountIds,
                                                                 keyFactory: storageFactory.slashingSpans(for:),
                                                                 engine: engine,
                                                                 itemsPerPage: 1000,
                                                                 operationQueue: operationQueue)

        XCTAssertEqual(allSlashings.count, slashedAccountIds.count)
    }

    func performRecommendations(for url: URL, itemsPerPage: Int = 1000) throws {
        // given
        let operationQueue = OperationQueue()

        let engine = WebSocketEngine(url: url, logger: logger)

        // when

        let storageKeyFactory = StorageKeyFactory()

        let currentEraKey = try storageKeyFactory.currentEra().toHex(includePrefix: true)
        let validatorsCountKey = try storageKeyFactory.stakingValidatorsCount().toHex(includePrefix: true)

        let allKeys = [
            currentEraKey,
            validatorsCountKey
        ]

        let infoOperation = JSONRPCOperation<[[String]], [StorageUpdate]>(engine: engine,
                                                                          method: RPCMethod.queryStorageAt,
                                                                          parameters: [allKeys])

        operationQueue.addOperations([infoOperation], waitUntilFinished: true)

        do {
            guard let result = try infoOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                    .first else {
                logger.error("No result found")
                return
            }

            let storageData = StorageUpdateData(update: result)

            guard let currentEra: UInt32 = try storageData.decodeUpdatedData(for: currentEraKey) else {
                logger.error("Unexpected empty era")
                return
            }

            guard let validatorsCount: UInt32 = try storageData.decodeUpdatedData(for: validatorsCountKey) else {
                logger.error("Unexpected empty validator count")
                return
            }

            logger.info("Current era: \(currentEra)")
            logger.info("Validators count: \(validatorsCount)")

            let electedPartialKey = try storageKeyFactory
                .eraStakers(for: currentEra).toHex(includePrefix: true)

            let validatorIds = try fetchAccountIds(for: electedPartialKey,
                                                   engine: engine,
                                                   itemsPerPage: UInt32(itemsPerPage),
                                                   operationQueue: operationQueue)

            logger.info("Elected validators count \(validatorIds.count)")

            let identities: [Data: IdentityRegistration] =
                try fetchItems(for: validatorIds,
                               keyFactory: storageKeyFactory.identity(for:),
                               engine: engine,
                               itemsPerPage: itemsPerPage,
                               operationQueue: operationQueue)
            logger.info("Identities count: \(identities.count)")

            let exposureKeyClosure = { (accountId: Data) in
                try storageKeyFactory.eraStakersExposure(for: currentEra, accountId: accountId)
            }

            let exposures: [Data: Exposure] = try fetchItems(for: validatorIds,
                                                             keyFactory: exposureKeyClosure,
                                                             engine: engine,
                                                             itemsPerPage: itemsPerPage,
                                                             operationQueue: operationQueue)

            XCTAssertEqual(exposures.count, validatorIds.count)

            let commissions: [Data: BigUInt] = try fetchItems(for: validatorIds,
                                                              keyFactory: storageKeyFactory.wannabeValidatorPrefs(for:),
                                                              engine: engine,
                                                              itemsPerPage: itemsPerPage,
                                                              operationQueue: operationQueue)

            logger.info("Slashed validators count: \(validatorIds.count - commissions.count)")

            let slashes: [Data: SlashingSpans] = try fetchItems(for: validatorIds,
                                                                keyFactory: storageKeyFactory.slashingSpans(for:),
                                                                engine: engine,
                                                                itemsPerPage: itemsPerPage,
                                                                operationQueue: operationQueue)

            logger.info("Slashed at least ones: \(slashes.count)")
        }
    }


    private func fetchAccountIds(for partialKey: String,
                         engine: JSONRPCEngine,
                         itemsPerPage: UInt32 = 100,
                         operationQueue: OperationQueue = OperationQueue()) throws -> [AccountId] {
        var lastKey: String?
        var accountIds: [AccountId] = []

        repeat {
            let request = PagedKeysRequest(key: partialKey, count: itemsPerPage, offset: lastKey)

            let operation = JSONRPCOperation<PagedKeysRequest, [String]>(engine: engine,
                                                                         method: RPCMethod.getStorageKeysPaged,
                                                                         parameters: request,
                                                                         timeout: 60)

            operationQueue.addOperations([operation], waitUntilFinished: true)

            let keys = try operation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            let ids: [AccountId] = try keys.map { key in
                    let accountId = try Data(hexString: key).suffix(32)
                    return AccountId(value: Data(accountId))
                }

            accountIds.append(contentsOf: ids)
            lastKey = keys.count == itemsPerPage ? keys.last : nil

        } while lastKey != nil

        return accountIds
    }

    func fetchItems<T: ScaleDecodable>(for accountIds: [AccountId],
                                       keyFactory: (Data) throws -> Data,
                                       engine: JSONRPCEngine,
                                       itemsPerPage: Int = 100,
                                       operationQueue: OperationQueue = OperationQueue()) throws
    -> [Data: T] {
        let accountCount = accountIds.count

        let requestsCount = accountCount % itemsPerPage == 0 ? accountCount / itemsPerPage : (accountCount / itemsPerPage) + 1

        let operations: [CompoundOperationWrapper<[Data: T]>] =
            try (0..<requestsCount).map { index in
            let pageStart = index * itemsPerPage
            let length = pageStart + itemsPerPage > accountCount ? accountCount - pageStart : itemsPerPage
            let pageEnd = pageStart + length

            let allKeys = try accountIds[pageStart..<pageEnd].map {
                try keyFactory($0.value).toHex(includePrefix: true)
            }

            let operation = JSONRPCOperation<[[String]], [StorageUpdate]>(engine: engine,
                                                                        method: RPCMethod.queryStorageAt,
                                                                        parameters: [allKeys])

            let mapOperation = ClosureOperation<[Data: T]> {
                 try operation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                    .map { StorageUpdateData(update: $0) }
                    .flatMap { $0.changes }
                    .reduce(into: [Data: T]()) { (result, change) in
                        guard let value = change.value else {
                            return
                        }

                        let accountId = change.key.suffix(32)

                        let scaleDecoder = try ScaleDecoder(data: value)
                        result[accountId] = try T(scaleDecoder: scaleDecoder)
                    }
            }

            mapOperation.addDependency(operation)

            return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [operation])
        }

        let mapOperation = ClosureOperation {
            try operations.reduce(into: [Data: T]()) { (result, operation) in
                let item = try operation.targetOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                result.merge(item) { (s1, s2) in s1 }
            }
        }

        for index in (0..<operations.count) {
            if index > 0 {
                operations[index].allOperations.forEach { $0.addDependency(operations[index-1].targetOperation) }
            }

            mapOperation.addDependency(operations[index].targetOperation)
        }

        let dependencies = operations.flatMap { $0.allOperations }

        operationQueue.addOperations(dependencies + [mapOperation], waitUntilFinished: true)

        return try mapOperation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
    }
}
