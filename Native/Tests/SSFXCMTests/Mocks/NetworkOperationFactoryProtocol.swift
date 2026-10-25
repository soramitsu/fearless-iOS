import UIKit
@testable import RobinHood
@testable import SSFNetwork

class NetworkOperationFactoryProtocolMock<U: Decodable>: NetworkOperationFactoryProtocol {
    // MARK: - fetchData<T: Decodable>

    var fetchDataFromCallsCount = 0
    var fetchDataFromCalled: Bool {
        fetchDataFromCallsCount > 0
    }

    var fetchDataFromReceivedUrl: URL?
    var fetchDataFromReceivedInvocations: [URL] = []
    var fetchDataFromReturnValue: BaseOperation<U>!
    var fetchDataFromClosure: ((URL) -> BaseOperation<U>)?

    func fetchData<T: Decodable>(from url: URL) -> BaseOperation<T> {
        fetchDataFromCallsCount += 1
        fetchDataFromReceivedUrl = url
        fetchDataFromReceivedInvocations.append(url)
        return fetchDataFromReturnValue as! BaseOperation<T>
    }
}
