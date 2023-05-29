import Foundation
import RobinHood

final class AwaitOperation<ResultType>: BaseOperation<ResultType> {
    /// Closure to execute to produce operation result.
    public let closure: () async throws -> ResultType

    /**
     *  Create closure operation.
     *
     *  - parameters:
     *    - closure: Closure to execute to produce operation result.
     */

    public init(closure: @escaping () async throws -> ResultType) {
        self.closure = closure
    }

    override public func main() {
        super.main()

        if isCancelled {
            return
        }

        if result != nil {
            return
        }

        Task {
            do {
                let executionResult = try await closure()
                result = .success(executionResult)
            } catch {
                result = .failure(error)
            }
        }
    }
}
