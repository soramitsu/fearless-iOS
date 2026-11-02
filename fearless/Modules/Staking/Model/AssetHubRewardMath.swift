import Foundation
import BigInt

/// Mirrors the runtime's Perbill floor operations, including the independent validator pot.
enum AssetHubRewardMath {
    struct Allocation {
        let reward: BigUInt
        let points: UInt32
        let totalPoints: UInt32
        let commission: BigUInt
        var incentive: BigUInt = 0
    }

    struct Exposure {
        let overview: ValidatorExposureMetadata
        let page: ValidatorExposurePage
        let pageIndex: UInt32
    }

    static let accuracy = BigUInt(1_000_000_000)

    static func fraction(_ numerator: BigUInt, of denominator: BigUInt, times value: BigUInt) throws -> BigUInt {
        guard denominator > 0, numerator <= denominator else { throw EraValidatorServiceError.unexpectedInfo }
        return (numerator * accuracy / denominator) * value / accuracy
    }

    static func payout(
        allocation: Allocation,
        exposure: Exposure,
        account: AccountId,
        validator: AccountId
    ) throws -> BigUInt {
        let overview = exposure.overview
        let page = exposure.page
        let pageIndex = exposure.pageIndex
        let commission = allocation.commission
        guard commission <= accuracy, overview.own <= overview.total,
              pageIndex < max(1, overview.pageCount),
              page.pageTotal == page.others.reduce(BigUInt.zero, { $0 + $1.value }),
              Set(page.others.map(\.who)).count == page.others.count else {
            throw EraValidatorServiceError.unexpectedInfo
        }
        guard overview.pageCount != 0 || (overview.nominatorCount == 0 && overview.own == overview.total && page.others.isEmpty) else {
            throw EraValidatorServiceError.unexpectedInfo
        }
        guard allocation.points > 0, allocation.totalPoints > 0, overview.total > 0 else { return 0 }
        let pool = try fraction(BigUInt(allocation.points), of: BigUInt(allocation.totalPoints), times: allocation.reward)
        let fee = pool * commission / accuracy
        let leftover = pool - fee
        let ownReward = try fraction(overview.own, of: overview.total, times: leftover)
        if account == validator {
            let stake = page.pageTotal + (pageIndex == 0 ? overview.own : 0)
            return try fraction(stake, of: overview.total, times: fee + ownReward)
                + fraction(stake, of: overview.total, times: allocation.incentive)
        }
        guard let stake = page.others.first(where: { $0.who == account })?.value else { return 0 }
        return try fraction(stake, of: overview.total - overview.own, times: leftover - ownReward)
    }
}
