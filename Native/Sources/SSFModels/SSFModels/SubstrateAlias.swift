import Foundation

public typealias AccountAddress = String
public typealias AccountId = Data
public typealias ParaId = UInt32
public typealias TrieIndex = UInt32
public typealias FundIndex = UInt32
public typealias BlockNumber = UInt32
public typealias BlockTime = UInt64
public typealias LeasingPeriod = UInt32
public typealias Slot = UInt64
public typealias SessionIndex = UInt32
public typealias Moment = UInt32
public typealias EraIndex = UInt32
public typealias EraRange = (start: EraIndex, end: EraIndex)
public typealias LeasingOffset = UInt32

public extension AccountId {
    static func matchHex(_ value: String) -> AccountId? {
        guard let data = try? Data(hexStringSSF: value) else {
            return nil
        }

        let accountIdLength = value.hasPrefix("0x")
            ? EthereumConstants.accountIdLength
            : SubstrateConstants.accountIdLength

        return data.count == accountIdLength ? data : nil
    }
}

public extension BlockNumber {
    func secondsTo(block: BlockNumber, blockDuration: UInt64) -> TimeInterval {
        let durationInSeconds = TimeInterval(blockDuration) / 1000
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
