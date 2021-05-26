import Foundation

typealias AccountAddress = String
typealias AccountId = Data
typealias ParaId = UInt32
typealias BlockNumber = UInt32
typealias BlockTime = UInt64
typealias LeasingPeriod = UInt32

extension AccountId {
    static func matchHex(_ value: String) -> AccountId? {
        guard let data = try? Data(hexString: value) else {
            return nil
        }

        return data.count == SubstrateConstants.accountIdLength ? data : nil
    }
}

extension BlockNumber {
    func secondsTo(block: BlockNumber, blockDuration: UInt64) -> TimeInterval {
        TimeInterval(block - self) * TimeInterval(blockDuration).seconds
    }
}
