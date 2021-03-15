import Foundation
@testable import fearless
import RobinHood

final class SingleValueProviderFactoryStub: SingleValueProviderFactoryProtocol {
    let price: AnySingleValueProvider<PriceData>
    let balance: AnyDataProvider<DecodedAccountInfo>
    let electionStatus: AnyDataProvider<DecodedElectionStatus>

    init(price: AnySingleValueProvider<PriceData>,
         balance: AnyDataProvider<DecodedAccountInfo>,
         electionStatus: AnyDataProvider<DecodedElectionStatus>) {
        self.price = price
        self.balance = balance
        self.electionStatus = electionStatus
    }

    func getPriceProvider(for assetId: WalletAssetId) -> AnySingleValueProvider<PriceData> {
        price
    }

    func getAccountProvider(for address: String, runtimeService: RuntimeCodingServiceProtocol) throws
    -> AnyDataProvider<DecodedAccountInfo> {
        balance
    }

    func getElectionStatusProvider(chain: Chain, runtimeService: RuntimeCodingServiceProtocol) throws -> AnyDataProvider<DecodedElectionStatus> {
        electionStatus
    }
}
