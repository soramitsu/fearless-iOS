import Foundation
import RobinHood

protocol JsonDataProviderFactoryProtocol {
    func getJson<T: Codable & Equatable>(for url: URL) -> AnySingleValueProvider<T>
}

class JsonDataProviderFactory: JsonDataProviderFactoryProtocol {
    static let shared = JsonDataProviderFactory(storageFacade: SubstrateDataStorageFacade.shared)

    private var providers: [String: WeakWrapper] = [:]

    let storageFacade: StorageFacadeProtocol

    init(storageFacade: StorageFacadeProtocol) {
        self.storageFacade = storageFacade
    }

    func getJson<T: Codable & Equatable>(for url: URL) -> AnySingleValueProvider<T> {
        let localKey = url.absoluteString

        if let provider = providers[localKey]?.target as? SingleValueProvider<T> {
            return AnySingleValueProvider(provider)
        }

        let source = JsonSingleProviderSource<T>(url: url)

        let repository: CoreDataRepository<SingleValueProviderObject, CDSingleValue> = storageFacade.createRepository()

        let singleValueProvider = SingleValueProvider(
            targetIdentifier: localKey,
            source: AnySingleValueProviderSource(source),
            repository: AnyDataProviderRepository(repository)
        )

        providers[localKey] = WeakWrapper(target: singleValueProvider)

        return AnySingleValueProvider(singleValueProvider)
    }
}
