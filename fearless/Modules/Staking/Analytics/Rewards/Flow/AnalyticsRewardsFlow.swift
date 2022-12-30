import Foundation
import UIKit
import SoraFoundation

enum AnalyticsRewardsFlow {
    case relaychain
    case parachain
}

protocol AnalyticsRewardsModelStateListener: AnyObject {
    func provideRewardsViewModel()
    func provideError(_ error: Error)
}

protocol AnalyticsRewardsViewModelState {
    var stateListener: AnalyticsRewardsModelStateListener? { get set }
    var historyAddress: String? { get }
    var hasPendingRewards: Bool { get }

    func setStateListener(_ stateListener: AnalyticsRewardsModelStateListener?)
}

struct AnalyticsRewardsDependencyContainer {
    let viewModelState: AnalyticsRewardsViewModelState
    let strategy: AnalyticsRewardsStrategy
    let viewModelFactory: AnalyticsRewardsFlowViewModelFactoryProtocol
}

protocol AnalyticsRewardsFlowViewModelFactoryProtocol {
    func createViewModel(
        viewModelState: AnalyticsRewardsViewModelState,
        priceData: PriceData?,
        period: AnalyticsPeriod,
        selectedChartIndex: Int?,
        locale: Locale
    ) -> AnalyticsRewardsViewModel?
}

protocol AnalyticsRewardsStrategy {
    func setup()
    func fetchRewards(address: AccountAddress)
}
