import SoraFoundation

protocol AnalyticsRewardDetailsViewProtocol: ControllerBackedProtocol, Localizable {
    func bind(viewModel: LocalizableResource<AnalyticsRewardDetailsViewModel>)
}

protocol AnalyticsRewardDetailsPresenterProtocol: AnyObject {
    func setup()
}

protocol AnalyticsRewardDetailsInteractorInputProtocol: AnyObject {}

protocol AnalyticsRewardDetailsInteractorOutputProtocol: AnyObject {}

protocol AnalyticsRewardDetailsWireframeProtocol: AnyObject {}

protocol AnalyticsRewardDetailsViewModelFactoryProtocol: AnyObject {
    func createViweModel(
        rewardModel: AnalyticsRewardDetailsModel
    ) -> LocalizableResource<AnalyticsRewardDetailsViewModel>
}
