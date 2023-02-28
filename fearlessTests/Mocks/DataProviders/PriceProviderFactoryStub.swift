//import Foundation
//@testable import fearless
//
//final class PriceProviderFactoryStub: PriceProviderFactoryProtocol {
//    func getPricesProvider(for pricesIds: [fearless.AssetModel.PriceId]) -> fearless.AnySingleValueProvider<[fearless.PriceData]> {
//        <#code#>
//    }
//    
//    let priceData: PriceData?
//
//    init(priceData: PriceData? = nil) {
//        self.priceData = priceData
//    }
//
//    func getPriceProvider(for priceId: AssetModel.PriceId) -> AnySingleValueProvider<PriceData> {
//        let provider = SingleValueProviderStub(item: priceData)
//        return AnySingleValueProvider(provider)
//    }
//}
