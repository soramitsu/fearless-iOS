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
        case .subsquid:
            return ParachainSubsquidHistoryOperationFactory(url: blockExplorer?.url)
        case .giantsquid:
            return ParachainSubsquidHistoryOperationFactory(url: blockExplorer?.url)
        case .sora:
            return ParachainSubsquidHistoryOperationFactory(url: blockExplorer?.url)
        case .alchemy, .etherscan, .reef:
            return nil
        }
    }
}
