enum AnalyticsViewState<ViewModel: Equatable>: Equatable {
    case loading
    case loaded(ViewModel)
    case error(String)
}
