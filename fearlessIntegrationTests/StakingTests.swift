import XCTest
@testable import fearless
import FearlessUtils
import IrohaCrypto
import RobinHood
import BigInt

class StakingTests: XCTestCase {
    let logger: LoggerProtocol = {
        let shared = Logger.shared
        shared.minLevel = .none
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

        let overview = try fetchOverview(engine: engine, operationQueue: operationQueue)

        logger.info("Active era: \(overview.activeEra)")
        logger.info("Current era: \(overview.currentEra)")
        logger.info("Session index: \(overview.sessionIndex)")
        logger.info("Validator count: \(overview.validatorCount)")
        logger.info("History depth: \(overview.historyDepth)")
        logger.info("Total issuance \(overview.totalIssuance.value)")
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

    func testViewPayoutMeasuring() throws {
        self.measure {
            do {
                let nodeUrl = URL(string: "wss://rpc.polkadot.io/")!
                let subscanUrl = WalletAssetId.dot.subscanUrl!.appendingPathComponent(SubscanApi.extrinsics)
                let nominatorAddress = "15cfSaBcTxNr8rV59cbhdMNCRagFr3GE6B3zZRsCp4QHHKPu"
                try performViewPayout(nodeUrl: nodeUrl,
                                      subscanUrl: subscanUrl,
                                      nominatorAddress: nominatorAddress,
                                      type: .polkadotMain)
            } catch {
                logger.error("Unexpected error: \(error)")
            }
        }
    }

    // MARK: Private

    func performViewPayout(nodeUrl: URL,
                           subscanUrl: URL,
                           nominatorAddress: String,
                           type: SNAddressType) throws {
        // given

        let engine = WebSocketEngine(url: nodeUrl, logger: logger)
        let operationQueue = OperationQueue()
        let accountId = try SS58AddressFactory().accountId(fromAddress: nominatorAddress, type: type)

        // when

        let overview = try fetchOverview(engine: engine, operationQueue: operationQueue)

        logger.info("Active era: \(overview.activeEra)")
        logger.info("Current era: \(overview.currentEra)")
        logger.info("History depth: \(overview.historyDepth)")

        let startEra = max(overview.currentEra - overview.historyDepth, 0)
        let endEra = max(overview.activeEra - 1, 0)
        let eraRange = startEra...endEra
        let validatorsRewardsOverview = try fetchValidatorsRewardOverview(eraRange: eraRange,
                                                                          engine: engine,
                                                                          operationQueue: operationQueue)

        let nominatorValidators = try fetchAllValidators(url: subscanUrl,
                                                         nominatorAddress: nominatorAddress,
                                                         type: type)

        logger.info("Targets count: \(nominatorValidators.count)")

        let erasExposures: ErasItems<Exposure> = try fetchErasItems(for: nominatorValidators.map({ AccountId(value: $0) }),
                                               eraRange: eraRange,
                                               keyFactory: StorageKeyFactory().eraStakersExposureClipped(for:accountId:),
                                               engine: engine,
                                               itemsPerPage: 1000,
                                               operationQueue: operationQueue)

        let newItems = erasExposures.items.map { mapping in
            mapping.compactMapValues { value in
                value.other.contains { $0.accoundId.value == accountId } ? value : nil
            }
        }

        let filteredExposures = ErasItems(startEra: erasExposures.startEra, items: newItems)

        let totalValidatorsCount = filteredExposures.items.map { $0.count }.reduce(0) { $0 + $1 }

        let validatorsMiscInfo = try fetchValidatorCommissionAndInfo(erasItems: filteredExposures,
                                                                     engine: engine,
                                                                     itemsPerPage: 1000,
                                                                     operationQueue: operationQueue)

        logger.info("Total validators: \(totalValidatorsCount)")
        logger.info("Validator ledgers: \(validatorsMiscInfo.ledgers.count)")
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

    func fetchErasItems<T: ScaleDecodable>(for accountIds: [AccountId],
                                           eraRange: ClosedRange<UInt32>,
                                           keyFactory: (UInt32, Data) throws -> Data,
                                           engine: JSONRPCEngine,
                                           itemsPerPage: Int = 1000,
                                           operationQueue: OperationQueue = OperationQueue()) throws -> ErasItems<T> {
        let allKeys = try eraRange.flatMap { era in
            try accountIds.map { accountId in
                try keyFactory(era, accountId.value).toHex(includePrefix: true)
            }
        }

        let keysCount = allKeys.count

        let requestsCount = keysCount % itemsPerPage == 0 ? keysCount / itemsPerPage : (keysCount / itemsPerPage) + 1

        let operations: [JSONRPCOperation<[[String]], [StorageUpdate]>] = (0..<requestsCount)
            .map { index in
            let pageStart = index * itemsPerPage
            let length = pageStart + itemsPerPage > keysCount ? keysCount - pageStart : itemsPerPage
            let pageEnd = pageStart + length

            let keys = Array(allKeys[pageStart..<pageEnd])

            let operation = JSONRPCOperation<[[String]], [StorageUpdate]>(engine: engine,
                                                                          method: RPCMethod.queryStorageAt,
                                                                          parameters: [keys])

            return operation
        }

        let mapOperation = ClosureOperation<StorageUpdateData> {
            let changes = try operations.flatMap {
                try $0.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            }.map { update in
                StorageUpdateData(update: update).changes
            }.flatMap { $0 }

            return StorageUpdateData(blockHash: nil, changes: changes)
        }

        for index in (0..<operations.count) {
            if index > 0 {
                operations[index].addDependency(operations[index-1])
            }

            mapOperation.addDependency(operations[index])
        }

        operationQueue.addOperations(operations + [mapOperation], waitUntilFinished: true)

        let storage = try mapOperation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)

        let items = try eraRange.map { era in
            try accountIds.reduce(into: [Data: T]()) { (result, account) in
                let key = try keyFactory(era, account.value).toHex(includePrefix: true)

                if let value: T = try storage.decodeUpdatedData(for: key) {
                    result[account.value] = value
                }
            }
        }

        return ErasItems(startEra: eraRange.first ?? 0, items: items)
    }

    func fetchValidatorCommissionAndInfo(erasItems: ErasItems<Exposure>,
                                         engine: JSONRPCEngine,
                                         itemsPerPage: Int = 100,
                                         operationQueue: OperationQueue = OperationQueue()) throws -> ValidatorMiscEraInfo {
        let storageKeyFactory = StorageKeyFactory()

        let accountIds = Set(erasItems.items.flatMap { $0.keys })

        let stashKeys = try accountIds.map { try storageKeyFactory
            .bondedKeyForId($0).toHex(includePrefix: true) }

        let commissionKeys = try erasItems.items.enumerated().flatMap { (index, item) in
            try item.keys.map {
                try storageKeyFactory.eraValidatorPrefs(for: erasItems.startEra + UInt32(index),
                                                        accountId: $0).toHex(includePrefix: true)
            }
        }

        let allKeys = stashKeys + commissionKeys

        let keysCount = allKeys.count

        let requestsCount = keysCount % itemsPerPage == 0 ? keysCount / itemsPerPage : (keysCount / itemsPerPage) + 1

        let operations: [JSONRPCOperation<[[String]], [StorageUpdate]>] = (0..<requestsCount)
            .map { index in
            let pageStart = index * itemsPerPage
            let length = pageStart + itemsPerPage > keysCount ? keysCount - pageStart : itemsPerPage
            let pageEnd = pageStart + length

            let keys = Array(allKeys[pageStart..<pageEnd])

            let operation = JSONRPCOperation<[[String]], [StorageUpdate]>(engine: engine,
                                                                          method: RPCMethod.queryStorageAt,
                                                                          parameters: [keys])

            return operation
        }

        let mapOperation = ClosureOperation<StorageUpdateData> {
            let changes = try operations.flatMap {
                try $0.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            }.map { update in
                StorageUpdateData(update: update).changes
            }.flatMap { $0 }

            return StorageUpdateData(blockHash: nil, changes: changes)
        }

        for index in (0..<operations.count) {
            if index > 0 {
                operations[index].addDependency(operations[index-1])
            }

            mapOperation.addDependency(operations[index])
        }

        operationQueue.addOperations(operations + [mapOperation], waitUntilFinished: true)

        let storage = try mapOperation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)

        let start = erasItems.startEra
        let end = start + UInt32(erasItems.items.count)
        let newItems: [[Data: ValidatorPrefs]] = try (start..<end).map { era in
            try erasItems.items[Int(era) - Int(start)].keys
                .reduce(into: [Data: ValidatorPrefs]()) { (result, accountId) in
                let storageKey = try storageKeyFactory
                    .eraValidatorPrefs(for: era, accountId: accountId).toHex(includePrefix: true)
                if let value: ValidatorPrefs = try storage.decodeUpdatedData(for: storageKey) {
                    result[accountId] = value
                }
            }
        }

        let controllers: [AccountId] = try accountIds.compactMap { accountId in
            let key = try storageKeyFactory.bondedKeyForId(accountId).toHex(includePrefix: true)

            let controller: AccountId? = try storage.decodeUpdatedData(for: key)

            return controller
        }

        let ledgers: [Data: StakingLedger] = try fetchItems(for: controllers,
                                                  keyFactory: storageKeyFactory.stakingInfoForControllerId(_:),
                                                  engine: engine,
                                                  itemsPerPage: 1000,
                                                  operationQueue: operationQueue)
            .values.reduce(into: [Data: StakingLedger]()) { (result, item) in
                result[item.stash.value] = item
            }

        return ValidatorMiscEraInfo(erasItems: ErasItems(startEra: erasItems.startEra, items: newItems),
                                    ledgers: ledgers)
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

    func fetchOverview(engine: JSONRPCEngine,
                       operationQueue: OperationQueue = OperationQueue()) throws
    -> StakingOverview {
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

        guard let result = try operation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                .first else {
            logger.error("No result found")
            throw BaseOperationError.unexpectedDependentResult
        }

        let storageData = StorageUpdateData(update: result)

        let activeEra: UInt32
        let currentEra: UInt32
        let sessionIndex: UInt32
        let validatorCount: UInt32
        let historyDepth: UInt32
        let totalIssuance: Balance

        if let activeEraData  = storageData.changes
                .first(where:{ $0.key.toHex(includePrefix: true) == activeEraKey})?.value {
            let scaleDecoder = try ScaleDecoder(data: activeEraData)
            activeEra = try UInt32(scaleDecoder: scaleDecoder)
        } else {
            activeEra = 0
        }

        if let currentEraData  = storageData.changes
                .first(where:{ $0.key.toHex(includePrefix: true) == currentEraKey})?.value {
            let scaleDecoder = try ScaleDecoder(data: currentEraData)
            currentEra = try UInt32(scaleDecoder: scaleDecoder)
        } else {
            currentEra = 0
        }

        if let sessionIndexData  = storageData.changes
                .first(where:{ $0.key.toHex(includePrefix: true) == sessionIndexKey})?.value {
            let scaleDecoder = try ScaleDecoder(data: sessionIndexData)
            sessionIndex = try UInt32(scaleDecoder: scaleDecoder)
        } else {
            sessionIndex = 0
        }

        if let validatorCountData  = storageData.changes
                .first(where:{ $0.key.toHex(includePrefix: true) == validatorsCountKey})?.value {
            let scaleDecoder = try ScaleDecoder(data: validatorCountData)
            validatorCount = try UInt32(scaleDecoder: scaleDecoder)
        } else {
            validatorCount = 0
        }

        if let historyDepthData = storageData.changes
            .first(where: { $0.key.toHex(includePrefix: true) == historyDepthKey})?.value {
            let scaleDecoder = try ScaleDecoder(data: historyDepthData)
            historyDepth = try UInt32(scaleDecoder: scaleDecoder)
        } else {
            historyDepth = 84
        }

        if let totalIssuanceData = storageData.changes
            .first(where: { $0.key.toHex(includePrefix: true) == totalIssuanceKey })?.value {
            let scaleDecoder = try ScaleDecoder(data: totalIssuanceData)
            totalIssuance = try Balance(scaleDecoder: scaleDecoder)
        } else {
            totalIssuance = Balance(value: 0)
        }

        return StakingOverview(currentEra: currentEra,
                               activeEra: activeEra,
                               historyDepth: historyDepth,
                               sessionIndex: sessionIndex,
                               validatorCount: validatorCount,
                               totalIssuance: totalIssuance)
    }

    func fetchValidatorsRewardOverview(eraRange: ClosedRange<UInt32>,
                                       engine: JSONRPCEngine,
                                       operationQueue: OperationQueue = OperationQueue()) throws
    -> ValidatorsRewardOverview {
        let storageKeyFactory = StorageKeyFactory()

        let totalRewardKeys = try eraRange.map { era in
            try storageKeyFactory.totalValidatorsReward(for: era).toHex(includePrefix: true)
        }

        let rewardPointsKeys = try eraRange.map { era in
            try storageKeyFactory.validatorsPoints(at: era).toHex(includePrefix: true)
        }

        let allKeys = totalRewardKeys + rewardPointsKeys

        let operation = JSONRPCOperation<[[String]], [StorageUpdate]>(engine: engine,
                                                                    method: RPCMethod.queryStorageAt,
                                                                    parameters: [allKeys])

        operationQueue.addOperations([operation], waitUntilFinished: true)

        guard let result = try operation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                .first else {
            logger.error("No result found")
            throw BaseOperationError.unexpectedDependentResult
        }

        let storageData = StorageUpdateData(update: result)

        let totalRewards: [Balance] = try totalRewardKeys.map { key in
            return (try storageData.decodeUpdatedData(for: key)) ?? Balance(value: BigUInt(0))
        }

        let rewardPoints: [EraRewardPoints] = try rewardPointsKeys.map { key in
            return (try storageData.decodeUpdatedData(for: key)) ?? EraRewardPoints(total: 0, individuals: [])
        }

        return ValidatorsRewardOverview(initialEra: eraRange.first ?? 0,
                                        totalValidatorsReward: totalRewards,
                                        rewardsPoints: rewardPoints)
    }

    func fetchAllValidators(url: URL, nominatorAddress: String, type: SNAddressType) throws -> Set<Data> {
        let addressFactory = SS58AddressFactory()

        var controllers: Set<String> = []
        var validators: Set<Data> = Set()
        let bondCalls = try fetchAllSubscanExtrinsics(url: url,
                                                      address: nominatorAddress,
                                                      module: "staking",
                                                      call: "bond")

        logger.info("Bond by stash \(nominatorAddress): \(bondCalls.count)")

        let setControllerCalls = try fetchAllSubscanExtrinsics(url: url,
                                                               address: nominatorAddress,
                                                               module: "staking",
                                                               call: "set_controller")

        logger.info("Controller changes by stash \(nominatorAddress): \(setControllerCalls.count)")

        let singleControllers = try parseSingleControllerCalls(bondCalls + setControllerCalls,
                                                               addressFactory: addressFactory,
                                                               type: type)
        controllers = controllers.union(singleControllers)

        let stashBatchAllCalls = try fetchAllSubscanExtrinsics(url: url,
                                                            address: nominatorAddress,
                                                            module: "utility",
                                                            call: "batch_all")

        logger.info("Batches by stash \(nominatorAddress): \(stashBatchAllCalls.count)")

        let stashBatchCalls = try fetchAllSubscanExtrinsics(url: url,
                                                            address: nominatorAddress,
                                                            module: "utility",
                                                            call: "batch")

        logger.info("BatchesAll by stash \(nominatorAddress): \(stashBatchCalls.count)")

        let batchControllers = try parseBatchControllerCalls(stashBatchCalls + stashBatchAllCalls,
                                                             addressFactory: addressFactory,
                                                             type: type)
        controllers = controllers.union(batchControllers)

        logger.info("Controllers: \(controllers)")

        let batchStashValidators = try parseBatchNominateCalls(stashBatchCalls + stashBatchAllCalls)
        validators = validators.union(batchStashValidators)

        logger.info("Stash validators: \(batchStashValidators.count)")

        for controller in controllers {
            let nominations = try fetchAllSubscanExtrinsics(url: url,
                                                            address: controller,
                                                            module: "staking",
                                                            call: "nominate")

            let singleValidators = try parseSingleNominateCalls(nominations)
            validators = validators.union(singleValidators)

            let batches = try fetchAllSubscanExtrinsics(url: url,
                                                        address: controller,
                                                        module: "utility",
                                                        call: "batch")

            let batchAll = try fetchAllSubscanExtrinsics(url: url,
                                                         address: controller,
                                                         module: "utility",
                                                         call: "batch_all")

            let batchValidators = try parseBatchNominateCalls(batches + batchAll)
            validators = validators.union(batchValidators)

            logger.info("Validators for controller \(controller): \(batchValidators.count)")
        }

        return validators
    }

    private func parseBatchNominateCalls(_ extrinsics: [SubscanExtrinsicItemData]) throws -> Set<Data> {
        try extrinsics.reduce(Set<Data>()) { (result, item) in
            let node = item.params?.nodes.arrayValue?.first { $0.name?.stringValue == "calls" }
            let calls = node?.value?.arrayValue

            let accountIds: [[Data]] = try (calls ?? []).compactMap { call in
                if call.call_module?.stringValue == "Staking",
                   call.call_function?.stringValue == "nominate" {
                    let arg = call.call_args?.arrayValue?.first { $0.name?.stringValue == "targets" }

                    let accountIds: [Data] = try (arg?.value?.arrayValue ?? []).compactMap { item in
                        if let hex = item.stringValue {
                            return try Data(hexString: hex)
                        } else {
                            return nil
                        }
                    }

                    return accountIds
                }

                return nil
            }

            return result.union(Set(accountIds.flatMap({ $0 })))
        }
    }

    private func parseSingleNominateCalls(_ extrinsics: [SubscanExtrinsicItemData]) throws -> Set<Data> {
        try extrinsics.reduce(Set<Data>()) { (result, item) in
            let node = item.params?.nodes.arrayValue?.first { $0.name?.stringValue == "targets" }
            let accountIds: [Data] = try (node?.value?.arrayValue ?? []).compactMap { hex in
                if let hex = hex.stringValue {
                    return try Data(hexString: hex)
                } else {
                    return nil
                }
            }

            return result.union(Set(accountIds))
        }
    }

    private func parseBatchControllerCalls(_ extrinsics: [SubscanExtrinsicItemData],
                                           addressFactory: SS58AddressFactoryProtocol,
                                           type: SNAddressType) throws -> Set<String> {
        try extrinsics.reduce(Set<String>()) { (result, item) in
            let node = item.params?.nodes.arrayValue?.first { $0.name?.stringValue == "calls" }
            let calls = node?.value?.arrayValue

            let addresses: [String] = try (calls ?? []).compactMap { call in
                if call.call_module?.stringValue == "Staking" &&
                    (call.call_function?.stringValue == "set_controller" ||
                        call.call_function?.stringValue == "bond") {
                    let arg = call.call_args?.arrayValue?.first { $0.name?.stringValue == "controller" }

                    if let accountIdHex = arg?.value?.stringValue {
                        let accountId = try Data(hexString: accountIdHex)
                        return try addressFactory
                            .address(fromPublicKey: AccountIdWrapper(rawData: accountId),
                                     type: type)
                    }

                    return nil
                }

                return nil
            }

            return result.union(Set(addresses))
        }
    }

    private func parseSingleControllerCalls(_ extrinsics: [SubscanExtrinsicItemData],
                                            addressFactory: SS58AddressFactoryProtocol,
                                            type: SNAddressType) throws -> Set<String> {
        try extrinsics.reduce(Set<String>()) { (result, item) in
            let node = item.params?.nodes.arrayValue?.first { $0.name?.stringValue == "controller" }

            if let accountIdHex = node?.value?.stringValue {
                let accountId = try Data(hexString: accountIdHex)
                let address = try addressFactory
                    .address(fromPublicKey: AccountIdWrapper(rawData: accountId),
                             type: type)
                return result.union([address])
            }

            return result
        }
    }

    func fetchAllSubscanExtrinsics(url: URL,
                                   address: String,
                                   module: String,
                                   call: String,
                                   pageLength: Int = 100) throws -> [SubscanExtrinsicItemData] {
        // given

        let subscan = SubscanOperationFactory()
        let operationQueue = OperationQueue()

        // when

        let firstPageRequest = ExtrinsicInfo(address: address,
                                             row: pageLength,
                                             page: 0,
                                             module: module,
                                             call: call)

        let firstPageOperation = subscan.fetchExtrinsics(url: url, info: firstPageRequest)

        operationQueue.addOperations([firstPageOperation], waitUntilFinished: true)

        let firstPage = try firstPageOperation
            .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

        let otherPageOperations: [BaseOperation<SubscanExtrinsicData>]

        if firstPage.count > pageLength {
            let remainedItemsCount = firstPage.count - pageLength
            let remainedPagesCount = remainedItemsCount % pageLength == 0 ? remainedItemsCount / pageLength
                : (remainedItemsCount / pageLength) + 1

            otherPageOperations = (0..<remainedPagesCount).map { pageIndex in
                let info = ExtrinsicInfo(address: address,
                                         row: pageLength,
                                         page: pageIndex + 1, module: module, call: call)
                return subscan.fetchExtrinsics(url: url, info: info)
            }
        } else {
            otherPageOperations = []
        }

        let allPagesOperations = [firstPageOperation] + otherPageOperations

        let allExtrinsicsOperation = ClosureOperation<[SubscanExtrinsicItemData]> {
            let items: [SubscanExtrinsicItemData] = try allPagesOperations.flatMap { operation in
                try operation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                    .extrinsics ?? []

            }

            return items
        }

        for otherOperation in otherPageOperations {
            allExtrinsicsOperation.addDependency(otherOperation)
        }

        operationQueue.addOperations(otherPageOperations + [allExtrinsicsOperation],
                                     waitUntilFinished: true)

        return try allExtrinsicsOperation
            .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
    }
}
