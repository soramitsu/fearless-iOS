import Foundation
import SSFModels
import UIKit

struct CrossChainTransactionStepViewModel {
    let status: CrossChainStepStatus
    let chain: ChainModel
    let parentChain: ChainModel?

    var statusIconImage: UIImage? {
        switch status {
        case .pending:
            return nil
        case .failed:
            return R.image.iconErrorFilled()
        case .success:
            return R.image.soraCardStatusSuccess()
        case .refund:
            return nil
        }
    }

    var chainIconViewModel: RemoteImageViewModel? {
        guard let icon = chain.icon else {
            return nil
        }

        return RemoteImageViewModel(url: icon)
    }

    var parentChainIconViewModel: RemoteImageViewModel? {
        guard let icon = parentChain?.icon else {
            return nil
        }

        return RemoteImageViewModel(url: icon)
    }
}
