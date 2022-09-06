import Foundation
import RobinHood

protocol ScamServiceOperationFactoryProtocol {
    func verifyOperation(for address: String) -> BaseOperation<ScamInfo?>
}

final class ScamService: ScamServiceOperationFactoryProtocol {
    // MARK: - Private properties

    private let repository: AnyDataProviderRepository<ScamInfo>

    // MARK: - Constructor

    init(repository: AnyDataProviderRepository<ScamInfo>) {
        self.repository = repository
    }

    // MARK: Public methods

    func verifyOperation(for address: String) -> BaseOperation<ScamInfo?> {
        repository.fetchOperation(by: address, options: RepositoryFetchOptions())
    }
}
