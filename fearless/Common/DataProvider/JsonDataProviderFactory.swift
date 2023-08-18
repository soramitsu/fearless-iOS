import Foundation
import RobinHood
import SSFUtils

protocol JsonDataProviderFactoryProtocol {
    func getJson<T: Codable & Equatable>(for url: URL) -> AnySingleValueProvider<T>
}

class JsonDataProviderFactory: JsonDataProviderFactoryProtocol {
    static let shared = JsonDataProviderFactory(storageFacade: SubstrateDataStorageFacade.shared)

    private var providers: [String: WeakWrapper] = [:]

    let useCache: Bool
    let storageFacade: StorageFacadeProtocol

    init(storageFacade: StorageFacadeProtocol, useCache: Bool = true) {
        self.storageFacade = storageFacade
        self.useCache = useCache
    }

    func getJson<T: Codable & Equatable>(for url: URL) -> AnySingleValueProvider<T> {
        let localKey = url.absoluteString

        if let provider = providers[localKey]?.target as? SingleValueProvider<T>, useCache {
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
