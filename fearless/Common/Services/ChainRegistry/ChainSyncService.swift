import Foundation
import RobinHood

protocol ChainSyncServiceProtocol {
    func syncUp()
}

final class ChainSyncService {
    let url: URL
    let repository: AnyDataProviderRepository<ChainModel>
    let dataFetchFactory: DataOperationFactoryProtocol

    init(
        url: URL,
        dataFetchFactory: DataOperationFactoryProtocol,
        repository: AnyDataProviderRepository<ChainModel>
    ) {
        self.url = url
        self.dataFetchFactory = dataFetchFactory
        self.repository = repository
    }
}

extension ChainSyncService: ChainSyncServiceProtocol {
    func syncUp() {}
}
