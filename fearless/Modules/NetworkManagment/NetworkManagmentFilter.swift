import Foundation
import RobinHood
import SSFModels

enum NetworkManagmentFilter: Identifiable {
    case chain(ChainModel.Id)
    case all
    case popular
    case favourite

    init(identifier: String?) {
        guard let identifier = identifier else {
            self = .all
            return
        }
        switch identifier {
        case "all":
            self = .all
        case "popular":
            self = .popular
        case "favourite":
            self = .favourite
        default:
            self = .chain(identifier)
        }
    }

    var identifier: String {
        switch self {
        case let .chain(id):
            return id
        case .all:
            return "all"
        case .popular:
            return "popular"
        case .favourite:
            return "favourite"
        }
    }

    var filterImage: ImageViewModelProtocol? {
        switch self {
        case .chain:
            return nil
        case .all:
            return BundleImageViewModel(image: R.image.iconNetwotkManagmentAll())
        case .popular:
            return BundleImageViewModel(image: R.image.iconNetwotkManagmentPopular())
        case .favourite:
            return BundleImageViewModel(image: R.image.iconNetwotkManagmentFavourite())
        }
    }

    var selectedChainId: ChainModel.Id? {
        switch self {
        case let .chain(id):
            return id
        case .all, .popular, .favourite:
            return nil
        }
    }

    var isAllFilter: Bool {
        switch self {
        case .all:
            return true
        case .popular, .favourite, .chain:
            return false
        }
    }

    var isChainSelected: Bool {
        switch self {
        case .chain:
            return true
        case .popular, .favourite, .all:
            return false
        }
    }

    var isPopularFilter: Bool {
        switch self {
        case .popular:
            return true
        case .all, .favourite, .chain:
            return false
        }
    }

    var isFavouriteFilter: Bool {
        switch self {
        case .favourite:
            return true
        case .popular, .all, .chain:
            return false
        }
    }
}
