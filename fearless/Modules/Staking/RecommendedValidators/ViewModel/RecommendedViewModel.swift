import Foundation

protocol RecommendedViewModelProtocol {
    var selectedCount: Int { get }
    var totalCount: Int { get }
}

struct RecommendedViewModel: RecommendedViewModelProtocol {
    let selectedCount: Int
    let totalCount: Int
}
