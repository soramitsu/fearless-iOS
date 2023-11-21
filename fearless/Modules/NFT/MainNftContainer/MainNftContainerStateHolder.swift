import SSFModels

final class MainNftContainerStateHolder {
    var filters: [FilterSet]
    var selectedChain: ChainModel?

    init(filters: [FilterSet]) {
        self.filters = filters
    }
}
