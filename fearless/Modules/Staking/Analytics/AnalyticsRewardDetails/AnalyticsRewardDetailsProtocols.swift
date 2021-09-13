import SoraFoundation

protocol AnalyticsRewardDetailsViewProtocol: ControllerBackedProtocol, Localizable {
    func bind(viewModel: LocalizableResource<AnalyticsRewardDetailsViewModel>)
}

protocol AnalyticsRewardDetailsPresenterProtocol: AnyObject {
    func setup()
    func handleBlockNumberAction()
}

protocol AnalyticsRewardDetailsInteractorInputProtocol: AnyObject {}

protocol AnalyticsRewardDetailsInteractorOutputProtocol: AnyObject {}

protocol AnalyticsRewardDetailsWireframeProtocol: ModalAlertPresenting, AlertPresentable, WebPresentable {}

protocol AnalyticsRewardDetailsViewModelFactoryProtocol: AnyObject {
    func createViweModel(
        rewardModel: AnalyticsRewardDetailsModel
    ) -> LocalizableResource<AnalyticsRewardDetailsViewModel>
}
