import Foundation
@testable import fearless

final class JsonDataProviderFactoryStub: JsonDataProviderFactoryProtocol {
    let sources: [URL: Any]

    init(sources: [URL: Any]) {
        self.sources = sources
    }

    func getJson<T>(
        for url: URL
    ) -> AnySingleValueProvider<T> where T : Decodable, T : Encodable, T : Equatable {
        let model: T?

        if let value = sources[url] as? T {
            model = value
        } else {
            model = nil
        }

        let provider = SingleValueProviderStub(item: model)
        return AnySingleValueProvider(provider)
    }
}
