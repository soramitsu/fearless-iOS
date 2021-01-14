import XCTest
@testable import fearless
import FearlessUtils
import IrohaCrypto
import RobinHood

class StakingTests: XCTestCase {
    func testNominationsFetch() throws {
        // given

        let address = "5CDayXd3cDCWpBkSXVsVfhE5bWKyTZdD3D1XUinR1ezS1sGn"
        let ss58Factory = SS58AddressFactory()
        let accountId = try ss58Factory.accountId(fromAddress: address, type: .genericSubstrate)

        let url = URL(string: "wss://westend-rpc.polkadot.io/")!
        let logger = Logger.shared
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
        let logger = Logger.shared
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
        let logger = Logger.shared
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
        let logger = Logger.shared
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

    func testFetchOverview() throws {
        // given

        let url = URL(string: "wss://rpc.polkadot.io/")!
        let logger = Logger.shared
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
                logger.debug("No result found")
                return
            }

            let storageData = StorageUpdateData(update: result)

            if let activeEraData  = storageData.changes
                    .first(where:{ $0.key.toHex(includePrefix: true) == activeEraKey})?.value {
                let scaleDecoder = try ScaleDecoder(data: activeEraData)
                let activeEra = try UInt32(scaleDecoder: scaleDecoder)
                logger.debug("Active era: \(activeEra)")
            } else {
                logger.debug("Empty active era")
            }

            if let currentEraData  = storageData.changes
                    .first(where:{ $0.key.toHex(includePrefix: true) == currentEraKey})?.value {
                let scaleDecoder = try ScaleDecoder(data: currentEraData)
                let currentEra = try UInt32(scaleDecoder: scaleDecoder)
                logger.debug("Current era: \(currentEra)")
            } else {
                logger.debug("Empty current era")
            }

            if let sessionIndexData  = storageData.changes
                    .first(where:{ $0.key.toHex(includePrefix: true) == sessionIndexKey})?.value {
                let scaleDecoder = try ScaleDecoder(data: sessionIndexData)
                let sessionIndex = try UInt32(scaleDecoder: scaleDecoder)
                logger.debug("Session index: \(sessionIndex)")
            } else {
                logger.debug("Empty session index")
            }

            if let validatorCountData  = storageData.changes
                    .first(where:{ $0.key.toHex(includePrefix: true) == validatorsCountKey})?.value {
                let scaleDecoder = try ScaleDecoder(data: validatorCountData)
                let validatorCount = try UInt32(scaleDecoder: scaleDecoder)
                logger.debug("Validator count: \(validatorCount)")
            } else {
                logger.debug("Empty validator count")
            }

            if let historyDepthData = storageData.changes
                .first(where: { $0.key.toHex(includePrefix: true) == historyDepthKey})?.value {
                let scaleDecoder = try ScaleDecoder(data: historyDepthData)
                let historyDepth = try UInt32(scaleDecoder: scaleDecoder)
                logger.debug("History depth: \(historyDepth)")
            } else {
                logger.debug("Empty history depth")
            }

            if let totalIssuanceData = storageData.changes
                .first(where: { $0.key.toHex(includePrefix: true) == totalIssuanceKey })?.value {
                let scaleDecoder = try ScaleDecoder(data: totalIssuanceData)
                let balance = try Balance(scaleDecoder: scaleDecoder)
                logger.debug("Total issuance \(balance.value)")
            } else {
                logger.debug("Empty total issuance")
            }

        } catch {
            logger.debug("Unexpected error: \(error)")
        }
    }

    func testRecommendations() throws {
        // given

        let url = URL(string: "wss://rpc.polkadot.io/")!
        let logger = Logger.shared
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
                logger.debug("No result found")
                return
            }

            let storageData = StorageUpdateData(update: result)

            guard let currentEra: UInt32 = try storageData.decodeUpdatedData(for: currentEraKey) else {
                logger.debug("Unexpected empty era")
                return
            }

            guard let validatorsCount: UInt32 = try storageData.decodeUpdatedData(for: validatorsCountKey) else {
                logger.debug("Unexpected empty validator count")
                return
            }

            logger.debug("Current era: \(currentEra)")
            logger.debug("Validators count: \(validatorsCount)")

            // fetching elected validator ids

            let validatorsPerPage: UInt32 = 1000
            let requestsCount = validatorsCount % validatorsPerPage == 0 ? validatorsCount / validatorsPerPage : (validatorsCount / validatorsPerPage) + 1

            let partialKey = try storageKeyFactory
                .eraStakers(for: currentEra).toHex(includePrefix: true)

            let operations = (0..<requestsCount).map { index in
                JSONRPCOperation<PagedKeysRequest, [String]>(engine: engine,
                                                             method: RPCMethod.getStorageKeysPaged,
                                                             timeout: 60)
            }

            for index in (0..<operations.count) {
                operations[index].configurationBlock = {
                    let request: PagedKeysRequest

                    do {
                        if index > 0 {
                            let lastKey = try operations[index-1].extractResultData()?.last
                            request = PagedKeysRequest(key: partialKey, count: validatorsPerPage, offset: lastKey)
                        } else {
                            request = PagedKeysRequest(key: partialKey, count: validatorsPerPage, offset: nil)
                        }

                        operations[index].parameters = request
                    } catch {
                        operations[index].result = .failure(error)
                    }
                }

                if index > 0 {
                    operations[index].addDependency(operations[index-1])
                }
            }

            let mapOperation = ClosureOperation<[AccountId]> {
                let accountIds: [[AccountId]] = try operations.map {
                    let keys = try $0.extractResultData(throwing: BaseOperationError.parentOperationCancelled)

                    let accountIds: [AccountId] = try keys.map { key in
                        let accountId = try Data(hexString: key).suffix(32)
                        return AccountId(value: Data(accountId))
                    }

                    return accountIds
                }

                return accountIds.flatMap { $0 }
            }

            if let lastOperation = operations.last {
                mapOperation.addDependency(lastOperation)
            }

            let electedIdsOperation = CompoundOperationWrapper(targetOperation: mapOperation,
                                                               dependencies: operations)

            operationQueue.addOperations(electedIdsOperation.allOperations, waitUntilFinished: true)

            let validatorIds = try electedIdsOperation.targetOperation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            logger.debug("Elected validators count \(validatorIds.count)")

            let identitiesOperation = try fetchIdentities(for: validatorIds,
                                                      engine: engine)

            operationQueue.addOperations(identitiesOperation.allOperations, waitUntilFinished: true)

            let identities = try identitiesOperation.targetOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            logger.debug("Identities count: \(identities.count)")

            let names: [String] = identities.compactMap { identity in
                guard case .raw(let data) = identity.info.display else {
                    return nil
                }

                return String(data: data, encoding: .utf8)
            }

            for name in names {
                logger.debug(name)
            }
        }
    }

    private func fetchIdentities(for accountIds: [AccountId], engine: JSONRPCEngine) throws
    -> CompoundOperationWrapper<[IdentityRegistration]> {
        let itemsPerPage = 100
        let accountCount = accountIds.count

        let requestsCount = accountCount % itemsPerPage == 0 ? accountCount / itemsPerPage : (accountCount / itemsPerPage) + 1

        let storageFactory = StorageKeyFactory()

        let operations: [CompoundOperationWrapper<[IdentityRegistration]>] =
            try (0..<requestsCount).map { index in
            let pageStart = index * itemsPerPage
            let length = pageStart + itemsPerPage > accountCount ? accountCount - pageStart : itemsPerPage
            let pageEnd = pageStart + length

            let allKeys = try accountIds[pageStart..<pageEnd].map {
                try storageFactory.identity(for: $0.value).toHex(includePrefix: true)
            }

            let operation = JSONRPCOperation<[[String]], [StorageUpdate]>(engine: engine,
                                                                        method: RPCMethod.queryStorageAt,
                                                                        parameters: [allKeys])

            let mapOperation = ClosureOperation<[IdentityRegistration]> {
                 try operation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                    .map { StorageUpdateData(update: $0) }
                    .flatMap { $0.changes }
                    .compactMap { change in
                        guard let value = change.value else {
                            return nil
                        }

                        let scaleDecoder = try ScaleDecoder(data: value)
                        return try IdentityRegistration(scaleDecoder: scaleDecoder)
                    }
            }

            mapOperation.addDependency(operation)

            return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [operation])
        }

        let mapOperation = ClosureOperation {
            try operations.flatMap {
                try $0.targetOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            }
        }

        for index in (0..<operations.count) {
            if index > 0 {
                operations[index].allOperations.forEach { $0.addDependency(operations[index-1].targetOperation) }
            }

            mapOperation.addDependency(operations[index].targetOperation)
        }

        let dependencies = operations.flatMap { $0.allOperations }

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }
}
