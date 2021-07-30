enum AnalyticsViewState<ViewModel> {
    case loading(Bool)
    case success(ViewModel)
    case error(Error)
}
