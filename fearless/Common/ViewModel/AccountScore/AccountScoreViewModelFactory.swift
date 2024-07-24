// import Foundation
//
// protocol AccountScoreViewModelFactory {
//    func buildViewModel(from accountStatistics: AccountStatistics) -> AccountScoreViewModel?
// }
//
// final class AccountScoreViewModelFactoryImpl: AccountScoreViewModelFactory {
//    func buildViewModel(from accountStatistics: AccountStatistics) -> AccountScoreViewModel? {
//        guard let score = accountStatistics.score else {
//            return nil
//        }
//
//        let rate = AccountScoreRate(from: score)
//        let intScore = ((score * 100.0) as NSDecimalNumber).intValue
//        return AccountScoreViewModel(accountScoreLabelText: "\(intScore)", rate: rate)
//    }
// }
