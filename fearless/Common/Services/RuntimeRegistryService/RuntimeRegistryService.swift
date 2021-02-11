import Foundation
import RobinHood

enum RuntimeRegistryServiceError: Error {
    case unexpectedCoderFetchingFailure
}

final class RuntimeRegistryService {
    private(set) var chain: Chain

    init(chain: Chain) {
        self.chain = chain
    }

    private func fetchCoderFactory(runCompletionIn queue: DispatchQueue?,
                                   executing closure: (RuntimeCoderFactoryProtocol) -> Void) {

    }
}

extension RuntimeRegistryService: RuntimeRegistryServiceProtocol {
    func update(to chain: Chain) {
        self.chain = chain
    }

    func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> {
        ClosureOperation {
            let semaphore = DispatchSemaphore(value: 0)

            var fetchedFactory: RuntimeCoderFactoryProtocol?

            self.fetchCoderFactory(runCompletionIn: nil) { factory in
                fetchedFactory = factory
                semaphore.signal()
            }

            semaphore.wait()

            guard let factory = fetchedFactory else {
                throw RuntimeRegistryServiceError.unexpectedCoderFetchingFailure
            }

            return factory
        }
    }
}
