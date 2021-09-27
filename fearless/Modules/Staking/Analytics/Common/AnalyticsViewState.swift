enum AnalyticsViewState<ViewModel> {
    case loading
    case loaded(ViewModel)
    case error(String)
}
