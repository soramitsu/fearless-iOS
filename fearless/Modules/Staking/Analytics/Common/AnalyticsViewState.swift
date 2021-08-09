enum AnalyticsViewState<ViewModel> {
    case loading(Bool)
    case loaded(ViewModel)
    case error(String)
}
