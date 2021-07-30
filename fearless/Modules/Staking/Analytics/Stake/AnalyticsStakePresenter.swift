import Foundation

final class AnalyticsStakePresenter {
    weak var view: AnalyticsStakeViewProtocol?
    let wireframe: AnalyticsStakeWireframeProtocol
    let interactor: AnalyticsStakeInteractorInputProtocol
    private let viewModelFactory: AnalyticsStakeViewModelFactory
    let logger: Logger?
    private var selectedPeriod = AnalyticsPeriod.default
    private var selectedPeriodDiff = 0
    private var priceData: PriceData?
    private var stakeData = [SubqueryStakeChangeData]()

    init(
        interactor: AnalyticsStakeInteractorInputProtocol,
        wireframe: AnalyticsStakeWireframeProtocol,
        viewModelFactory: AnalyticsStakeViewModelFactory,
        logger: Logger? = nil
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.logger = logger
    }

    private func updateView() {
        let viewModel = viewModelFactory.createViewModel(
            from: stakeData,
            priceData: nil,
            period: selectedPeriod,
            periodDelta: selectedPeriodDiff
        )
        view?.reload(viewModel: viewModel)
    }
}

extension AnalyticsStakePresenter: AnalyticsStakePresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func didSelectPeriod(_ period: AnalyticsPeriod) {
        selectedPeriod = period
        selectedPeriodDiff = 0
        updateView()
    }

    func didSelectPrevious() {
        selectedPeriodDiff -= 1
        updateView()
    }

    func didSelectNext() {
        selectedPeriodDiff += 1
        updateView()
    }
}

extension AnalyticsStakePresenter: AnalyticsStakeInteractorOutputProtocol {
    func didReceieve(stakeDataResult: Result<[SubqueryStakeChangeData], Error>) {
        switch stakeDataResult {
        case let .success(data):
            stakeData = data
            updateView()
        case let .failure(error):
            logger?.error(error.localizedDescription)
        }
    }
}
