import Foundation

protocol AnalyticsPresenterBaseProtocol: AnyObject {
    func setup()
    func reload()
    func didSelectPeriod(_ period: AnalyticsPeriod)
    func didSelectXValue(_ index: Int)
    func didUnselectXValue()
    func handleReward(_ rewardModel: AnalyticsRewardDetailsModel)
}

protocol AnalyticsBaseViewModel: Equatable {
    var sections: [AnalyticsRewardSection] { get }
    var emptyListDescription: String { get }
    var isEmpty: Bool { get }
}
