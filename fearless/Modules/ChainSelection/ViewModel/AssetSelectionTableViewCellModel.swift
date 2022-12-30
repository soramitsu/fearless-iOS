import Foundation

enum AssetSelectionStakingType: Equatable {
    case normal(chainAsset: ChainAsset?)
    case pool(chainAsset: ChainAsset?)

    var title: String? {
        switch self {
        case .normal:
            return nil
        case .pool:
            return "POOL"
        }
    }

    var chainAsset: ChainAsset? {
        switch self {
        case let .normal(chainAsset):
            return chainAsset
        case let .pool(chainAsset):
            return chainAsset
        }
    }
}

final class AssetSelectionTableViewCellModel: SelectableViewModelProtocol {
    let title: String
    let subtitle: String?
    let icon: ImageViewModelProtocol?
    let stakingType: AssetSelectionStakingType

    init(
        title: String,
        subtitle: String?,
        icon: ImageViewModelProtocol?,
        isSelected: Bool,
        stakingType: AssetSelectionStakingType
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.stakingType = stakingType
        self.isSelected = isSelected
    }
}
