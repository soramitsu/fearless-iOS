import Foundation

struct WalletHistoryFilter: OptionSet {
    typealias RawValue = UInt8

    static let transfers = WalletHistoryFilter(rawValue: 1 << 0)
    static let rewardsAndSlashes = WalletHistoryFilter(rawValue: 1 << 1)
    static let extrinsics = WalletHistoryFilter(rawValue: 1 << 2)
    static let all: WalletHistoryFilter = [.transfers, .rewardsAndSlashes, .extrinsics]

    let rawValue: UInt8

    init(rawValue: RawValue) {
        self.rawValue = rawValue
    }
}

extension WalletHistoryFilter {
    init(string: String?) {
        if let string = string, let filterValue = UInt8(string) {
            self.init(rawValue: filterValue)
        } else {
            self = .all
        }
    }

    func toString() -> String { String(rawValue) }
}
