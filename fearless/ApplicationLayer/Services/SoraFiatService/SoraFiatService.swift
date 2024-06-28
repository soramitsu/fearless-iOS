import Foundation
import RobinHood
import sorawallet

protocol FiatServiceObserverProtocol: AnyObject {
    func processFiat(data: [FiatData])
}

protocol FiatServiceProtocol: AnyObject {
    func getFiat() async -> [FiatData]
}

struct FiatServiceObserver {
    weak var observer: FiatServiceObserverProtocol?
}

final class FiatService {
    static let shared = FiatService()
    private let operationManager = OperationManager()
    private var expiredDate = Date()
    private var fiatData: [FiatData] = []
    private var observers: [FiatServiceObserver] = []
    private let syncQueue = DispatchQueue(label: "co.jp.soramitsu.sora.fiat.service")

    private func updateFiatData() {
        let queryOperation = SubqueryFiatInfoOperation<[FiatData]>(baseUrl: ApplicationConfig.shared.soraSubqueryUrl)
        queryOperation.completionBlock = { [weak self] in
            guard let self, let response = try? queryOperation.extractNoCancellableResultData() else {
                return
            }
            self.fiatData = response
            self.expiredDate = Date().addingTimeInterval(20)
        }
        operationManager.enqueue(operations: [queryOperation], in: .transient)
    }

    private func updateFiatDataAwait() async -> [FiatData] {
        let queryOperation = SubqueryFiatInfoOperation<[FiatData]>(baseUrl: ApplicationConfig.shared.soraSubqueryUrl)
        operationManager.enqueue(operations: [queryOperation], in: .transient)

        return await withCheckedContinuation { continuation in
            queryOperation.completionBlock = {
                guard let response = try? queryOperation.extractNoCancellableResultData() else {
                    continuation.resume(returning: [])
                    return
                }
                continuation.resume(returning: response)
            }
        }
    }

    private func updateFiatData(with data: [FiatData]) async {
        fiatData = data
        expiredDate = Date().addingTimeInterval(600)
    }
}

extension FiatService: FiatServiceProtocol {
    func getFiat() async -> [FiatData] {
        if expiredDate < Date() {
            updateFiatData()
        }

        if !fiatData.isEmpty {
            return fiatData
        }

        let response = await updateFiatDataAwait()
        await updateFiatData(with: response)

        return response
    }
}
