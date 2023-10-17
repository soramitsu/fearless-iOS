import Foundation
import UIKit
import SSFModels

struct WalletConnectProposalViewModel {
    let indexPath: IndexPath?
    let cells: [WalletConnectProposalCellModel]
    let expiryDate: String?

    lazy var selectedWalletIds: [String]? = {
        let metaIds = cells.compactMap {
            switch $0 {
            case let .wallet(viewModel):
                return viewModel.isSelected ? viewModel.metaId : nil
            default:
                return nil
            }
        }
        return metaIds.isNotEmpty ? metaIds : nil
    }()
}

enum WalletConnectProposalCellModel {
    case dAppInfo(DetailsViewModel)
    case requiredNetworks(DetailsViewModel)
    case optionalNetworks(DetailsViewModel)
    case requiredExpandable(ExpandableViewModel)
    case optionalExpandable(ExpandableViewModel)
    case wallet(WalletViewModel)

    init?(optionalNetworksCaseViewModel: DetailsViewModel?) {
        guard let viewModel = optionalNetworksCaseViewModel else {
            return nil
        }
        self = .optionalNetworks(viewModel)
    }

    init?(optionalNetworkExpadableViewModel: ExpandableViewModel?) {
        guard let viewModel = optionalNetworkExpadableViewModel else {
            return nil
        }
        self = .optionalExpandable(viewModel)
    }

    struct DetailsViewModel {
        let title: String
        let subtitle: String
        let icon: ImageViewModelProtocol?
    }

    struct ExpandableViewModel {
        let cellTitle: String
        let chain: String
        let methods: String
        let events: String
        let isExpanded: Bool

        func toggle() -> Self {
            ExpandableViewModel(
                cellTitle: cellTitle,
                chain: chain,
                methods: methods,
                events: events,
                isExpanded: !isExpanded
            )
        }
    }

    struct WalletViewModel {
        let metaId: String
        let walletName: String
        let isSelected: Bool

        func toggle() -> Self {
            WalletViewModel(
                metaId: metaId,
                walletName: walletName,
                isSelected: !isSelected
            )
        }
    }
}
