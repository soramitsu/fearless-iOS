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

            stakersOperation.parameters = PagedKeysRequest(key: key, count: 1000)
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

        let params = PagedKeysRequest(key: key, count: 1000)
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

        // then

        operationQueue.addOperations([operation], waitUntilFinished: true)

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
}
