import Foundation
import BigInt

typealias AccountAddress = String
typealias AccountId = Data
typealias ParaId = UInt32
typealias TrieIndex = UInt32
typealias FundIndex = UInt32
typealias BlockNumber = UInt32
typealias BlockTime = UInt64
typealias LeasingPeriod = UInt32
typealias Slot = UInt64
typealias SessionIndex = UInt32
typealias Moment = UInt32
typealias EraIndex = UInt32
typealias EraRange = (start: EraIndex, end: EraIndex)
typealias LeasingOffset = UInt32

extension AccountId {
    static func matchHex(_ value: String) -> AccountId? {
        guard let data = try? Data(hexString: value) else {
            return nil
        }

        let accountIdLength = value.hasPrefix("0x")
            ? EthereumConstants.accountIdLength
            : SubstrateConstants.accountIdLength

        return data.count == accountIdLength ? data : nil
    }
}

extension BlockNumber {
    func secondsTo(block: BlockNumber, blockDuration: UInt64) -> TimeInterval {
        let durationInSeconds = TimeInterval(blockDuration).seconds
        let diffBlock = TimeInterval(Int(block) - Int(self))
        let seconds = diffBlock * durationInSeconds
        return seconds
    }

    func toHex() -> String {
        var blockNumber = self

        return Data(
            Data(bytes: &blockNumber, count: MemoryLayout<UInt32>.size).reversed()
        ).toHex(includePrefix: true)
    }
}
