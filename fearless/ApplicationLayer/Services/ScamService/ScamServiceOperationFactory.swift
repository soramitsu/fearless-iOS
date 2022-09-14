import Foundation
import RobinHood

protocol ScamServiceOperationFactoryProtocol {
    func fetchScamInfoOperation(for address: String) -> BaseOperation<ScamInfo?>
    func fetchAllOperations() -> BaseOperation<[ScamInfo]>
}

final class ScamServiceOperationFactory: ScamServiceOperationFactoryProtocol {
    // MARK: - Private properties

    private let repository: AnyDataProviderRepository<ScamInfo>

    // MARK: - Constructor

    init(repository: AnyDataProviderRepository<ScamInfo>) {
        self.repository = repository
    }

    // MARK: Public methods

    func fetchScamInfoOperation(for address: String) -> BaseOperation<ScamInfo?> {
        repository.fetchOperation(by: address, options: RepositoryFetchOptions())
    }

    func fetchAllOperations() -> BaseOperation<[ScamInfo]> {
        repository.fetchAllOperation(with: RepositoryFetchOptions())
    }
}
