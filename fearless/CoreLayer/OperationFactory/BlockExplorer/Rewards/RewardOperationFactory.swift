import Foundation
import RobinHood
import BigInt
import SSFModels

protocol RewardHistoryResponseProtocol {
    func rewardHistory(for address: String) -> [RewardHistoryItemProtocol]
}

enum RewardHistoryRequestError: Error {
    case invalidParameters
}

enum RewardHistoryRequestValidator {
    private static let maximumAddressLength = 128

    static func isValid(
        address: AccountAddress,
        startTimestamp: Int64?,
        endTimestamp: Int64?,
        maximumTimestamp: Int64 = .max
    ) -> Bool {
        let addressScalars = address.unicodeScalars
        guard
            (1 ... maximumAddressLength).contains(addressScalars.count),
            addressScalars.allSatisfy({ scalar in
                switch scalar.value {
                case 48 ... 57, 65 ... 90, 97 ... 122:
                    return true
                default:
                    return false
                }
            })
        else {
            return false
        }

        if let startTimestamp,
           startTimestamp < 0 || startTimestamp > maximumTimestamp {
            return false
        }
        if let endTimestamp,
           endTimestamp < 0 || endTimestamp > maximumTimestamp {
            return false
        }
        if let startTimestamp, let endTimestamp, startTimestamp > endTimestamp {
            return false
        }

        return true
    }
}

enum RewardAmountParser {
    static let maximumDecimalDigits = 78

    static func parse(_ value: String) -> BigUInt? {
        let bytes = value.utf8

        guard
            !bytes.isEmpty,
            bytes.count <= maximumDecimalDigits,
            bytes.allSatisfy({ (48 ... 57).contains($0) }),
            bytes.count == 1 || bytes.first != 48
        else {
            return nil
        }

        return BigUInt(value, radix: 10)
    }
}

struct RewardHistoryAttribution: Equatable {
    let validatorAddress: AccountAddress
    let era: EraIndex

    init?(validatorAddress: AccountAddress?, era: UInt64?) {
        guard
            let validatorAddress,
            validatorAddress == validatorAddress.trimmingCharacters(in: .whitespacesAndNewlines),
            !validatorAddress.isEmpty,
            let era,
            let exactEra = EraIndex(exactly: era)
        else {
            return nil
        }

        self.validatorAddress = validatorAddress
        self.era = exactEra
    }
}

protocol RewardHistoryItemProtocol {
    var id: String { get }
    var type: SubqueryDelegationAction { get }
    var timestampInSeconds: String { get }
    var blockNumber: Int { get }
    var amount: BigUInt { get }
    var attribution: RewardHistoryAttribution? { get }
}

extension RewardHistoryItemProtocol {
    var attribution: RewardHistoryAttribution? { nil }
}

protocol CollatorAprInfoProtocol {
    var collatorId: String { get }
    var apr: Double { get }
}

protocol CollatorAprResponse {
    var collatorAprInfos: [CollatorAprInfoProtocol] { get }
}

enum RewardOperationFactory {
    static func factory(chain: ChainModel) -> RewardOperationFactoryProtocol {
        let blockExplorer = chain.externalApi?.staking
        let type = blockExplorer?.type ?? .subsquid

        switch type {
        case .subquery:
            return SubqueryRewardOperationFactory(url: blockExplorer?.url)
        case .subsquid:
            return ArrowsquidRewardOperationFactory(url: blockExplorer?.url)
        case .giantsquid:
            return GiantsquidRewardOperationFactory(url: blockExplorer?.url, chain: chain)
        case .sora:
            return SoraRewardOperationFactory(url: blockExplorer?.url, chain: chain)
        case .reef:
            return ReefRewardOperationFactory(url: blockExplorer?.url, chain: chain)
        // .oklink was removed in newer SSFModels; treat like generic explorers
        case .etherscan:
            return GiantsquidRewardOperationFactory(url: blockExplorer?.url, chain: chain)
        default:
            return GiantsquidRewardOperationFactory(url: blockExplorer?.url, chain: chain)
        }
    }
}

protocol RewardOperationFactoryProtocol {
    func createHistoryOperation(
        address: String,
        startTimestamp: Int64?,
        endTimestamp: Int64?
    ) -> BaseOperation<RewardOrSlashResponse>

    func createDelegatorRewardsOperation(
        address: String,
        startTimestamp: Int64?,
        endTimestamp: Int64?
    ) -> BaseOperation<RewardHistoryResponseProtocol>

    func createAprOperation(
        for idsClosure: @escaping () throws -> [AccountId],
        dependingOn roundIdOperation: BaseOperation<String>
    ) -> BaseOperation<CollatorAprResponse>

    func createLastRoundOperation() -> BaseOperation<String>
}

extension RewardOperationFactoryProtocol {
    func createHistoryOperation(address: String) -> BaseOperation<RewardOrSlashResponse> {
        createHistoryOperation(address: address, startTimestamp: nil, endTimestamp: nil)
    }
}
