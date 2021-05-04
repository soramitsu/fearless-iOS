import Foundation
@testable import fearless

final class ExtrinsicServiceFactoryStub: ExtrinsicServiceFactoryProtocol {
    let extrinsicService: ExtrinsicServiceProtocol

    init(extrinsicService: ExtrinsicServiceProtocol) {
        self.extrinsicService = extrinsicService
    }

    func createService(accountItem: AccountItem) -> ExtrinsicServiceProtocol {
        return extrinsicService
    }
}
