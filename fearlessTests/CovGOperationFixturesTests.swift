import Foundation
import RobinHood
import SSFModels
import XCTest
@testable import fearless

enum CovGOperationFixtures {
    static let asset = AssetModel(
        id: "0", name: "Token", symbol: "UNIT", precision: 12,
        isUtility: true, isNative: true, type: .normal
    )

    static func chain(id: String = "1", history: String? = "https://history.invalid/graphql") throws -> ChainModel {
        let explorer = try history.map {
            try XCTUnwrap(ChainModel.BlockExplorer(type: "subquery", url: XCTUnwrap(URL(string: $0))))
        }
        return ChainModel(
            rank: nil, disabled: false, chainId: id, paraId: nil, name: "Coverage chain",
            assets: [asset], xcm: nil, nodes: [], addressPrefix: 42, icon: nil,
            options: [], externalApi: explorer.map { .init(history: $0) },
            iosMinAppVersion: nil, identityChain: nil
        )
    }

    static func result<T>(_ operation: BaseOperation<T>) throws -> T {
        try XCTUnwrap(operation.result).get()
    }

    static func run<T>(_ wrapper: CompoundOperationWrapper<T>) throws -> T {
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)
        return try result(wrapper.targetOperation)
    }

    static func run<T>(_ operation: BaseOperation<T>) throws -> T {
        operation.start()
        return try result(operation)
    }

    static func network<T, U>(_ wrapper: CompoundOperationWrapper<U>, as _: T.Type) throws -> NetworkOperation<T> {
        try XCTUnwrap(wrapper.allOperations.compactMap { $0 as? NetworkOperation<T> }.first)
    }

    static func respond<T>(_ operation: NetworkOperation<T>, json: String) throws {
        let result = operation.resultFactory.createResult(data: Data(json.utf8), response: nil, error: nil)
        _ = try result.get()
        operation.result = result
    }

    static func query<T>(_ operation: NetworkOperation<T>) throws -> String {
        let request = try operation.requestFactory.createRequest()
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        let object = try JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody))
        return try XCTUnwrap((object as? [String: String])?["query"])
    }

    static func checkNetworkFailures<T>(_ operation: NetworkOperation<T>) {
        XCTAssertThrowsError(try operation.resultFactory.createResult(data: Data("invalid".utf8), response: nil, error: nil).get())
        let error = NSError(domain: "CovG.network", code: 73)
        XCTAssertThrowsError(try operation.resultFactory.createResult(data: nil, response: nil, error: error).get()) {
            XCTAssertEqual(($0 as NSError).code, 73)
        }
        XCTAssertThrowsError(try operation.resultFactory.createResult(data: nil, response: nil, error: nil).get())
    }
}
