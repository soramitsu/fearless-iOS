import Foundation
import RobinHood
import SSFModels

protocol ParachainHistoryOperationFactory {
    func createUnstakingHistoryOperation(
        delegatorAddress: String,
        collatorAddress: String
    ) -> BaseOperation<DelegatorHistoryResponse>
}

enum ParachainHistoryOperationFactoryAssembly {
    static func factory(blockExplorer: ChainModel.BlockExplorer?) -> ParachainHistoryOperationFactory? {
        let type = blockExplorer?.type ?? .subsquid

        switch type {
        case .subquery:
            return ParachainSubqueryHistoryOperationFactory(url: blockExplorer?.url)
        case .subsquid, .giantsquid, .sora:
            return ParachainSubsquidHistoryOperationFactory(url: blockExplorer?.url)
        default:
            return nil
        }
    }
}
