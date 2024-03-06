import Foundation
import SSFUtils
import SSFModels
import RobinHood

protocol CrowdloanService {
    func fetchContributions(accountId: AccountId) async throws -> CrowdloanContributionDict
}

final class CrowdloanServiceDefault {
    private let crowdloanOperationFactory: CrowdloanOperationFactoryProtocol
    private let runtimeService: RuntimeCodingServiceProtocol
    private let connection: JSONRPCEngine
    private let chainAsset: ChainAsset
    private let operationManager: OperationManagerProtocol

    init(
        crowdloanOperationFactory: CrowdloanOperationFactoryProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        connection: JSONRPCEngine,
        chainAsset: ChainAsset,
        operationManager: OperationManagerProtocol
    ) {
        self.crowdloanOperationFactory = crowdloanOperationFactory
        self.runtimeService = runtimeService
        self.connection = connection
        self.chainAsset = chainAsset
        self.operationManager = operationManager
    }

    private func provideCrowdloans() async throws -> [Crowdloan] {
        try await withCheckedThrowingContinuation { continuation in
            let crowdloanWrapper = crowdloanOperationFactory.fetchCrowdloansOperation(
                connection: connection,
                runtimeService: runtimeService
            )
            crowdloanWrapper.targetOperation.completionBlock = {
                do {
                    let crowdloans = try crowdloanWrapper.targetOperation.extractNoCancellableResultData()
                    return continuation.resume(with: .success(crowdloans))
                } catch {
                    return continuation.resume(throwing: error)
                }
            }

            operationManager.enqueue(operations: crowdloanWrapper.allOperations, in: .transient)
        }
    }
}

extension CrowdloanServiceDefault: CrowdloanService {
    func fetchContributions(accountId: AccountId) async throws -> CrowdloanContributionDict {
        let crowdloans = try await provideCrowdloans()

        return try await withCheckedThrowingContinuation { continuation in
            let contributionsOperation: BaseOperation<[CrowdloanContributionResponse]> =
                OperationCombiningService(operationManager: operationManager) {
                    crowdloans.map { crowdloan in
                        self.crowdloanOperationFactory.fetchContributionOperation(
                            connection: self.connection,
                            runtimeService: self.runtimeService,
                            accountId: accountId,
                            trieOrFundIndex: crowdloan.fundInfo.trieOrFundIndex
                        )
                    }
                }.longrunOperation()

            contributionsOperation.completionBlock = {
                do {
                    let contributions = try contributionsOperation.extractNoCancellableResultData().toDict()
                    return continuation.resume(with: .success(contributions))
                } catch {
                    return continuation.resume(throwing: error)
                }
            }

            operationManager.enqueue(operations: [contributionsOperation], in: .transient)
        }
    }
}
