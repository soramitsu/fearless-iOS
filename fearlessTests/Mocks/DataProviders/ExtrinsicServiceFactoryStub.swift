import Foundation
@testable import fearless

final class ExtrinsicServiceFactoryStub: ExtrinsicServiceFactoryProtocol {
    let extrinsicService: ExtrinsicServiceProtocol
    let signingWraper: SigningWrapperProtocol

    init(extrinsicService: ExtrinsicServiceProtocol, signingWraper: SigningWrapperProtocol) {
        self.extrinsicService = extrinsicService
        self.signingWraper = signingWraper
    }

    func createService(accountItem: AccountItem) -> ExtrinsicServiceProtocol {
        return extrinsicService
    }

    func createSigningWrapper(
        accountItem: AccountItem,
        connectionItem: ConnectionItem
    ) -> SigningWrapperProtocol {
        signingWraper
    }
}
