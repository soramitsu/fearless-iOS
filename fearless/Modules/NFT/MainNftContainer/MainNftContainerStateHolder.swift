import SSFModels

final class MainNftContainerStateHolder {
    var filters: [FilterSet]
    var selectedChains: [ChainModel]?

    init(filters: [FilterSet]) {
        self.filters = filters
    }
}
