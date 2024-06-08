import Foundation
import RobinHood
import SSFSingleValueCache

protocol JsonDataProviderFactoryProtocol {
    func getJson<T: Codable & Equatable>(for url: URL) throws -> AnySingleValueProvider<T>
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

    func getJson<T: Codable & Equatable>(for url: URL) throws -> AnySingleValueProvider<T> {
        let localKey = url.absoluteString

        if let provider = providers[localKey]?.target as? SingleValueProvider<T>, useCache {
            return AnySingleValueProvider(provider)
        }

        let source = JsonSingleProviderSource<T>(url: url)

        let repository: CoreDataRepository<SingleValueProviderObject, CDSingleValue> = SingleValueCacheRepositoryFactoryDefault().createSingleValueCacheRepository()

        let singleValueProvider = SingleValueProvider(
            targetIdentifier: localKey,
            source: AnySingleValueProviderSource(source),
            repository: AnyDataProviderRepository(repository)
        )

        providers[localKey] = WeakWrapper(target: singleValueProvider)

        return AnySingleValueProvider(singleValueProvider)
    }
}
