import Foundation
import RobinHood
import SSFModels
import SSFUtils
import XCTest
@testable import fearless

final class CovGExplorerNetworkTests: XCTestCase {
    func testBlockscoutBuildsNativeAndTokenRoutesAndFiltersZeroAmounts() throws {
        for token in [false, true] {
            let asset = AssetModel(id: "contract", name: "Token", symbol: "T", precision: 12, isUtility: !token, isNative: !token, ethereumType: token ? .erc20 : .normal)
            let wrapper = try BlockscoutHistoryOperationFactory().fetchTransactionHistoryOperation(
                asset: asset, chain: CovGOperationFixtures.chain(), address: "owner", filters: [], pagination: Pagination(count: 10)
            )
            let network = try CovGOperationFixtures.network(wrapper, as: BlockscoutHistoryResponse.self)
            let request = try network.requestFactory.createRequest()
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url?.path, "/graphql/addresses/owner/" + (token ? "token-transfers" : "transactions"))
            XCTAssertEqual(request.url?.query, token ? "token=contract" : nil)
            CovGOperationFixtures.checkNetworkFailures(network)
            let nodes = [1, 3, 0].map { index in
                """
                {"timestamp":"2024-01-0\(index + 1)T00:00:00.000Z","from":{"hash":"owner"},"to":{"hash":"peer"},
                "hash":"hash-\(index)","value":"\(index)000000000000","total":{"value":"\(index)000000000000","decimals":"12"}}
                """
            }.joined(separator: ",")
            try CovGOperationFixtures.respond(network, json: "{\"items\":[\(nodes)]}")
            let page = try XCTUnwrap(CovGOperationFixtures.run(wrapper))
            XCTAssertEqual(page.transactions.map(\.transactionId), ["hash-3", "hash-1"])
            XCTAssertEqual(page.transactions.map(\.amount.stringValue), ["3", "1"])
            XCTAssertNil(page.context)
        }
    }

    func testFireRequestMappingSortingAndMissingResponse() throws {
        for empty in [false, true] {
            let wrapper = try history(FireHistoryOperationFactory())
            let network = try CovGOperationFixtures.network(wrapper, as: FireHistoryResponse.self)
            XCTAssertEqual(try network.requestFactory.createRequest().url?.path, "/graphql/transactions/address/owner")
            CovGOperationFixtures.checkNetworkFailures(network)
            let nodes = [1, 3, 0].map { index in
                """
                {"hash":"hash-\(index)","createdAt":"2024-01-0\(index + 1)T00:00:00.000Z","fromAddress":"owner","toAddress":"peer",
                "value":"\(index)000000000000","gas":"2","gasPrice":"3"}
                """
            }.joined(separator: ",")
            try CovGOperationFixtures.respond(network, json: empty ? "{}" : "{\"data\":{\"count\":3,\"transactions\":[\(nodes)]}}")
            let page = try XCTUnwrap(CovGOperationFixtures.run(wrapper))
            XCTAssertEqual(page.transactions.map(\.transactionId), empty ? [] : ["hash-3", "hash-1"])
            XCTAssertNil(page.context)
        }
    }

    func testViscanRequestMappingSortingAndMissingResponse() throws {
        for empty in [false, true] {
            let wrapper = try history(ViscanHistoryOperationFactory())
            let network = try CovGOperationFixtures.network(wrapper, as: ViscanHistoryResponse.self)
            let request = try network.requestFactory.createRequest()
            XCTAssertEqual(request.url?.path, "/graphql/transaction/list")
            XCTAssertEqual(request.url?.query, "account=owner")
            CovGOperationFixtures.checkNetworkFailures(network)
            let nodes = [1, 3, 0].map { index in
                """
                {"hash":"hash-\(index)","timestamp":\(index),"from":"owner","to":"peer","value":"\(index)000000000000","fee":0.1}
                """
            }.joined(separator: ",")
            try CovGOperationFixtures.respond(network, json: empty ? "{}" : "{\"data\":[\(nodes)]}")
            let page = try XCTUnwrap(CovGOperationFixtures.run(wrapper))
            XCTAssertEqual(page.transactions.map(\.transactionId), empty ? [] : ["hash-3", "hash-1"])
            XCTAssertNil(page.context)
        }
    }

    func testZChainRequestMappingSortingAndMissingResponse() throws {
        for empty in [false, true] {
            let wrapper = try history(ZChainHistoryOperationFactory())
            let network = try CovGOperationFixtures.network(wrapper, as: ZChainHistoryResponse.self)
            let request = try network.requestFactory.createRequest()
            XCTAssertEqual(request.url?.path, "/graphql/transaction")
            XCTAssertEqual(request.url?.query, "a=owner")
            CovGOperationFixtures.checkNetworkFailures(network)
            let nodes = [1, 3, 0].map { index in
                """
                {"h":"hash-\(index)","ti":\(index),"f":{"a":"owner"},"t":{"a":"peer"},"v":"\(index)000000000000","tf":"0"}
                """
            }.joined(separator: ",")
            try CovGOperationFixtures.respond(network, json: empty ? "{}" : "{\"data\":[\(nodes)]}")
            let page = try XCTUnwrap(CovGOperationFixtures.run(wrapper))
            XCTAssertEqual(page.transactions.map(\.transactionId), empty ? [] : ["hash-3", "hash-1"])
            XCTAssertNil(page.context)
        }
    }

    func testAllExplorersReportMissingURLWithoutSchedulingNetwork() throws {
        let factories: [HistoryOperationFactoryProtocol] = [
            BlockscoutHistoryOperationFactory(), FireHistoryOperationFactory(), ViscanHistoryOperationFactory(), ZChainHistoryOperationFactory()
        ]
        for factory in factories {
            let wrapper = try factory.fetchTransactionHistoryOperation(
                asset: CovGOperationFixtures.asset, chain: CovGOperationFixtures.chain(history: nil), address: "owner",
                filters: [], pagination: Pagination(count: 10)
            )
            XCTAssertEqual(wrapper.allOperations.count, 1)
            XCTAssertThrowsError(try CovGOperationFixtures.run(wrapper)) {
                guard case SubqueryHistoryOperationFactoryError.urlMissing = $0 else { return XCTFail("Unexpected error \($0)") }
            }
        }
    }

    private func history(_ factory: HistoryOperationFactoryProtocol) throws -> CompoundOperationWrapper<AssetTransactionPageData?> {
        try factory.fetchTransactionHistoryOperation(
            asset: CovGOperationFixtures.asset, chain: CovGOperationFixtures.chain(), address: "owner",
            filters: [], pagination: Pagination(count: 10)
        )
    }
}

final class CovGNetworkFactoryTests: XCTestCase {
    func testCoinGeckoRequestAndMultipleCurrenciesIgnoreMissingPrices() throws {
        let operation = CoingeckoOperationFactory().fetchPriceOperation(for: ["token", "missing"], currencies: [.defaultCurrency(), .euro()])
        let network = try XCTUnwrap(operation as? NetworkOperation<[PriceData]>)
        let request = try network.requestFactory.createRequest()
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        let items = try XCTUnwrap(URLComponents(url: XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?.queryItems)
        XCTAssertEqual(items.first { $0.name == "ids" }?.value, "token,missing")
        XCTAssertEqual(items.first { $0.name == "vs_currencies" }?.value, "usd,eur")
        XCTAssertEqual(items.first { $0.name == "include_24hr_change" }?.value, "true")
        CovGOperationFixtures.checkNetworkFailures(network)
        try CovGOperationFixtures.respond(network, json: #"{"token":{"usd":1.25,"usd_24h_change":-2.5,"eur":1.1}}"#)
        let prices = try CovGOperationFixtures.run(operation)
        XCTAssertEqual(prices.map(\.currencyId), ["usd", "eur"])
        XCTAssertEqual(prices.map(\.price), ["1.25", "1.1"])
        XCTAssertEqual(prices.map(\.fiatDayChange), [Decimal(string: "-2.5"), 0])
        XCTAssertEqual(prices.map(\.priceId), ["token", "token"])
    }

    func testGithubPhishingListDecodesValidAddressesAndIgnoresInvalidEntries() throws {
        let key = Data(repeating: 7, count: 32)
        let address = try key.toAddress(using: .substrate(42))
        let url = try XCTUnwrap(URL(string: "https://data.invalid/phishing.json"))
        let network = GitHubOperationFactory().fetchPhishingListOperation(url)
        XCTAssertEqual(try network.requestFactory.createRequest().url, url)
        XCTAssertEqual(try network.requestFactory.createRequest().httpMethod, "GET")
        CovGOperationFixtures.checkNetworkFailures(network)
        try CovGOperationFixtures.respond(network, json: "{\"source\":[\"\(address)\",\"invalid\"],\"ignored\":42}")
        let items = try CovGOperationFixtures.run(network)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.publicKey, key.toHex())
        XCTAssertEqual(items.first?.source, "source")
        XCTAssertTrue(try network.resultFactory.createResult(data: Data("[]".utf8), response: CovGOperationFixtures.response(), error: nil).get().isEmpty)
    }

    func testDataDownloadDisablesCacheAndPreservesRawBytes() throws {
        let url = try XCTUnwrap(URL(string: "https://data.invalid/raw"))
        let operation = DataOperationFactory().fetchData(from: url)
        let network = try XCTUnwrap(operation as? NetworkOperation<Data>)
        let request = try network.requestFactory.createRequest()
        XCTAssertEqual(request.url, url)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalAndRemoteCacheData)
        let bytes = Data([0, 1, 255])
        XCTAssertEqual(try network.resultFactory.createResult(data: bytes, response: CovGOperationFixtures.response(), error: nil).get(), bytes)
    }
}
