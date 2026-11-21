import RobinHood
import SSFModels
import XCTest
@testable import fearless

final class CovFPayoutIndexerTests: XCTestCase {
    func testIndexerRequestsUsePostJsonAndSelectedAccount() throws {
        let asset = CovFFixtures.asset()
        let address = try AddressFactory.address(for: CovFFixtures.account, chain: asset.chain)
        let url = try XCTUnwrap(URL(string: "https://payouts.invalid/graphql"))
        for factory in factories(url: url, asset: asset) {
            let wrapper = factory.createResolutionOperation(for: address, eraRangeClosure: { EraRange(1, 2) })
            let operation = try XCTUnwrap(wrapper.targetOperation as? NetworkOperation<[AccountId]>)
            let request = try operation.requestFactory.createRequest()
            XCTAssertEqual(request.url, url)
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            let body = try XCTUnwrap(request.httpBody)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
            XCTAssertTrue(try XCTUnwrap(json["query"]).contains(address))
        }
    }

    func testIndexerResponsesResolveValidatorAddressesAndIgnoreRowsWithoutAddress() throws {
        let asset = CovFFixtures.asset()
        let address = try AddressFactory.address(for: CovFFixtures.account, chain: asset.chain)
        let url = try XCTUnwrap(URL(string: "https://payouts.invalid/graphql"))
        let payloads: [[String: Any]] = [
            ["data": ["query": ["eraValidatorInfos": ["nodes": [["address": address], [:]]]]]],
            ["data": ["eraValidatorInfos": [["address": address], [:]]]],
            ["data": ["stakingEraNominators": [["nominations": [["validator": ["validator": ["id": address]]]]], [:]]]]
        ]
        for (factory, payload) in zip(factories(url: url, asset: asset), payloads) {
            let operation = try XCTUnwrap(factory.createResolutionOperation(for: address, eraRangeClosure: { nil })
                .targetOperation as? NetworkOperation<[AccountId]>)
            let data = try JSONSerialization.data(withJSONObject: payload)
            let ok = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
            let result = operation.resultFactory.createResult(data: data, response: ok, error: nil)
            XCTAssertEqual(try result.get(), [CovFFixtures.account])
            for empty in [Data("{}".utf8), Data("invalid".utf8)] {
                XCTAssertEqual(try operation.resultFactory.createResult(data: empty, response: ok, error: nil).get(), [])
            }
            XCTAssertThrowsError(try operation.resultFactory.createResult(data: data, response: nil, error: nil).get())
        }
    }

    func testIndexerTransportErrorsArePreserved() throws {
        let asset = CovFFixtures.asset()
        let url = try XCTUnwrap(URL(string: "https://payouts.invalid/graphql"))
        let failure = NSError(domain: "indexer", code: 8)
        for factory in factories(url: url, asset: asset) {
            let operation = try XCTUnwrap(factory.createResolutionOperation(for: "address", eraRangeClosure: { nil })
                .targetOperation as? NetworkOperation<[AccountId]>)
            XCTAssertThrowsError(try operation.resultFactory.createResult(data: nil, response: nil, error: failure).get()) {
                XCTAssertEqual($0 as NSError, failure)
            }
        }
    }

    private func factories(url: URL, asset: ChainAsset) -> [PayoutValidatorsFactoryProtocol] {
        [SubqueryPayoutValidatorsForNominatorFactory(url: url, chainAsset: asset),
         SubsquidPayoutValidatorsForNominatorFactory(url: url, chainAsset: asset),
         SoraSubsquidPayoutValidatorsForNominatorFactory(url: url, chainAsset: asset)]
    }
}
