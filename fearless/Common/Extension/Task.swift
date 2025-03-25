import Foundation

extension Task where Failure == Never, Success == Void {
    init(
        priority: TaskPriority? = nil,
        operation: @escaping () async throws -> Void,
        catch: @escaping (Error) -> Void
    ) {
        self.init(priority: priority) {
            do {
                _ = try await operation()
            } catch {
                `catch`(error)
            }
        }
    }
}
