import SoraFoundation

protocol AnalyticsStakeViewProtocol: ControllerBackedProtocol, Localizable {
    func reload(viewModel: LocalizableResource<AnalyticsStakeViewModel>)
}

protocol AnalyticsStakePresenterProtocol: AnyObject {
    func setup()
    func didSelectPeriod(_ period: AnalyticsPeriod)
    func didSelectPrevious()
    func didSelectNext()
}

protocol AnalyticsStakeInteractorInputProtocol: AnyObject {
    func setup()
}

protocol AnalyticsStakeInteractorOutputProtocol: AnyObject {
    func didReceieve(stakeDataResult: Result<[SubqueryStakeChangeData], Error>)
}

protocol AnalyticsStakeWireframeProtocol: AnyObject {}
