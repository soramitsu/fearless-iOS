import Foundation
import Web3PromiseKit

final class RetryOperation {
    private let maxRetries: Int
    private let retryDelay: TimeInterval
    
    init(maxRetries: Int = 3, retryDelay: TimeInterval = 1.0) {
        self.maxRetries = maxRetries
        self.retryDelay = retryDelay
    }
    
    func execute<T>(
        operation: () async throws -> T,
        onError: ((Error) -> Void)? = nil
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                return try await operation()
            } catch {
                lastError = error
                
                if attempt < maxRetries {
                    try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                }
            }
        }
        
        if let error = lastError {
            throw error
        }
        
        throw CommonError.undefined
    }
    
    func executeWithPromise<T>(
        operation: @escaping () -> Promise<T>,
        onError: ((Error) -> Void)? = nil
    ) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in            
            func attempt(attemptNumber: Int) {
                operation()
                    .done { result in
                        continuation.resume(returning: result)
                    }
                    .catch { error in
                        if attemptNumber < self.maxRetries {
                            DispatchQueue.main.asyncAfter(deadline: .now() + self.retryDelay) {
                                print("RetryOperation did retry")
                                attempt(attemptNumber: attemptNumber + 1)
                            }
                        } else {
                            continuation.resume(throwing: error)
                        }
                    }
            }
            
            attempt(attemptNumber: 1)
        }
    }
} 
