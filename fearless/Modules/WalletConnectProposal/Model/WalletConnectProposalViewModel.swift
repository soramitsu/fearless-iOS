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

    init?(requiredNetworksViewModel: DetailsViewModel?) {
        guard let viewModel = requiredNetworksViewModel else {
            return nil
        }
        self = .requiredNetworks(viewModel)
    }

    init?(requiredExpandableViewModel: ExpandableViewModel?) {
        guard let viewModel = requiredExpandableViewModel else {
            return nil
        }
        self = .requiredExpandable(viewModel)
    }

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

    func deselectWallet() -> Self {
        switch self {
        case let .wallet(walletViewModel):
            var viewModel = walletViewModel
            viewModel.isSelected = false
            return .wallet(viewModel)
        default: return self
        }
    }

    struct DetailsViewModel {
        let title: String
        let subtitle: String
        let icon: ImageViewModelProtocol?
    }

    struct ExpandableViewModel {
        let cellTitle: String

        let title: String

        let title2: String?
        let subtitle2: String?

        let title3: String?
        let subtitle3: String?

        let isExpanded: Bool

        func toggle() -> Self {
            ExpandableViewModel(
                cellTitle: cellTitle,
                title: title,
                title2: title2,
                subtitle2: subtitle2,
                title3: title3,
                subtitle3: subtitle3,
                isExpanded: !isExpanded
            )
        }

        func isVisibleSection2() -> Bool {
            [title2?.isNotEmpty, subtitle2?.isNotEmpty]
                .compactMap { $0 }
                .allSatisfy { $0 }
        }

        func isVisibleSection3() -> Bool {
            [title3?.isNotEmpty, subtitle3?.isNotEmpty]
                .compactMap { $0 }
                .allSatisfy { $0 }
        }
    }

    struct WalletViewModel {
        let metaId: String
        let walletName: String
        var isSelected: Bool

        func toggle() -> Self {
            WalletViewModel(
                metaId: metaId,
                walletName: walletName,
                isSelected: !isSelected
            )
        }
    }
}
