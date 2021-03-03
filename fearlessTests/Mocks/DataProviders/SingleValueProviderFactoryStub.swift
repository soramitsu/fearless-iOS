import Foundation
@testable import fearless
import RobinHood

final class SingleValueProviderFactoryStub: SingleValueProviderFactoryProtocol {
    let price: AnySingleValueProvider<PriceData>
    let balance: AnyDataProvider<DecodedAccountInfo>

    init(price: AnySingleValueProvider<PriceData>, balance: AnyDataProvider<DecodedAccountInfo>) {
        self.price = price
        self.balance = balance
    }

    func getPriceProvider(for assetId: WalletAssetId) -> AnySingleValueProvider<PriceData> {
        price
    }

    func getAccountProvider(for address: String, runtimeService: RuntimeCodingServiceProtocol) throws
    -> AnyDataProvider<DecodedAccountInfo> {
        balance
    }
}
