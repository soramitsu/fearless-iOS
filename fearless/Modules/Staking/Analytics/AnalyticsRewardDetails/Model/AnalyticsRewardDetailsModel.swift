import BigInt
import Foundation

protocol AnalyticsRewardDetailsModel {
    var txHash: String { get }
    var date: Date { get }
    var amount: BigUInt { get }
}
