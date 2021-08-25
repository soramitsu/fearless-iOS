import BigInt
import Foundation

protocol AnalyticsRewardDetailsModel {
    var eventId: String { get }
    var date: Date { get }
    var amount: BigUInt { get }
}
