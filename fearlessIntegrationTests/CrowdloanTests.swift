import XCTest
@testable import fearless
import SSFUtils
import RobinHood
import SoraKeystore
import IrohaCrypto

class CrowdloanTests: XCTestCase {
    func testFetchContributions() {
        do {
            let operationManager = OperationManagerFacade.sharedManager
            let chainId = Chain.kusama.genesisHash
            let selectedAccountId = try "FiLhWLARS32oxm4s64gmEMSppAdugsvaAx1pCjweTLGn5Rf".toAccountId()

            let chainRegistry = ChainRegistryFactory.createDefaultRegistry(
                from: SubstrateStorageTestFacade()
            )

            chainRegistry.syncUp()

            let syncCompletionExpectation = XCTestExpectation()
            chainRegistry.chainsSubscribe(self, runningInQueue: .main) { changes in
                if !changes.isEmpty {
                    syncCompletionExpectation.fulfill()
                }
            }

            wait(for: [syncCompletionExpectation], timeout: 10)

            guard let connection = chainRegistry.getConnection(for: chainId) else {
                throw ChainRegistryError.connectionUnavailable
            }

            guard let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
                throw ChainRegistryError.runtimeMetadaUnavailable
            }

            let storageRequestFactory = StorageRequestFactory(
                remoteFactory: StorageKeyFactory(),
                operationManager: operationManager
            )

            let crowdloanOperationFactory = CrowdloanOperationFactory(
                requestOperationFactory: storageRequestFactory,
                operationManager: operationManager
            )

            let crowdloansWrapper = crowdloanOperationFactory.fetchCrowdloansOperation(
                connection: connection,
                runtimeService: runtimeService
            )

            let contributionsOperation: BaseOperation<[CrowdloanContributionResponse]> =
                OperationCombiningService(operationManager: operationManager) {
                    let crowdloans = try crowdloansWrapper.targetOperation.extractNoCancellableResultData()
                    return crowdloans.map { crowdloan in
                        crowdloanOperationFactory.fetchContributionOperation(
                            connection: connection,
                            runtimeService: runtimeService,
                            accountId: selectedAccountId,
                            trieOrFundIndex: crowdloan.fundInfo.trieOrFundIndex
                        )
                    }
                }.longrunOperation()

            contributionsOperation.addDependency(crowdloansWrapper.targetOperation)

            let expectation = XCTestExpectation()

            contributionsOperation.completionBlock = {
                expectation.fulfill()
            }

            let allOperations = crowdloansWrapper.allOperations + [contributionsOperation]

            operationManager.enqueue(operations: allOperations, in: .transient)

            wait(for: [expectation], timeout: 30)

            let contributions = try contributionsOperation.extractNoCancellableResultData()

            Logger.shared.info("Did receive contributions")
            Logger.shared.info("\(contributions)")

        } catch {
            XCTFail("Did receive error: \(error)")
        }
    }
    
    func testCustomCrowdloanFlows() {
        let jsonDecoder = JSONDecoder()
        func decodeText<T: Decodable>(_ text: String, as type: T.Type) throws -> T {
            try jsonDecoder.decode(T.self, from: text.data(using: .utf8)!)
        }
        
        let karuraJsonText = """
        {
            "paraid": "2000",
            "name": "Karura",
            "token": "KAR",
            "description": "All-in-one DeFi hub of Kusama",
            "website": "https://acala.network/karura",
            "icon": "https://raw.githubusercontent.com/polkadot-js/apps/master/packages/apps-config/src/ui/logos/chains/karura.svg",
            "rewardRate": 12,
            "flow": {
                "name": "karura"
            }
        }
        """
        
        do {
            let karura = try decodeText(karuraJsonText, as: CrowdloanDisplayInfo.self)
            guard let flow = karura.flowIfSupported else {
                XCTFail()
                return
            }
            
            switch flow {
            case .karura: XCTAssert(true)
            default: XCTFail()
            }
        } catch {
            XCTFail("Karura decode error: \(error)")
        }
        
        let moonbeamJsonText = """
         {
            "paraid": "2002",
            "name": "Moonbeam",
            "token": "GLMR",
            "description": "Ethereum-compatible smart contract parachain on Polkadot",
            "website": "https://moonbeam.network",
            "icon": "https://raw.githubusercontent.com/polkadot-js/apps/master/packages/apps-config/src/ui/logos/nodes/moonbeam.png",
            "flow": {
                "name": "moonbeam",
                "data": {
                    "devApiUrl": "https://wallet-test.api.purestake.xyz",
                    "prodApiUrl": "https://wallet-test.api.purestake.xyz"
                }
            }
          }
        """
        
        do {
            let moonbeam = try decodeText(moonbeamJsonText, as: CrowdloanDisplayInfo.self)
            guard let flow = moonbeam.flowIfSupported else {
                XCTFail()
                return
            }
            
            switch flow {
            case let .moonbeam(data):
                let moonbeamJson = try JSONSerialization.jsonObject(with: moonbeamJsonText.data(using: .utf8)!, options: .init()) as! [String: Any]
                let moonbeamFlow = moonbeamJson["flow"] as! [String: Any]
                let moonbeamData = moonbeamFlow["data"] as! [String: Any]
                XCTAssertEqual(data.devApiUrl, moonbeamData["devApiUrl"] as! String)
                XCTAssertEqual(data.prodApiUrl, moonbeamData["prodApiUrl"] as! String)
            default: XCTFail()
            }
        } catch {
            XCTFail("Karura decode error: \(error)")
        }
    }
}
