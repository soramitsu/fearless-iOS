import Foundation
import BigInt
import FearlessUtils
import SoraFoundation

typealias BalanceLocks = [BalanceLock]

struct BalanceLock: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case amount
        case reasons
    }

    @BytesCodable var identifier: Data
    @StringCodable var amount: BigUInt
    let reasons: LockReason

    var displayId: String? {
        String(
            data: identifier,
            encoding: .utf8
        )?.trimmingCharacters(in: .whitespaces)
    }
}

extension BalanceLocks {
    func mainLocks() -> BalanceLocks {
        LockType.locksOrder.compactMap { lockType in
            self.first(where: { lock in
                lock.displayId == lockType.rawValue
            })
        }
    }

    func auxLocks() -> BalanceLocks {
        compactMap { lock in
            guard LockType(rawValue: lock.displayId ?? "") != nil else {
                return lock
            }

            return nil
        }.sorted { lhs, rhs in
            lhs.amount > rhs.amount
        }
    }
}


enum LockReason: UInt8, Codable {
    case fee
    case misc
    case all
}

enum LockType: String {
    case staking
    case vesting
    case democracy = "democrac"

    static var locksOrder: [Self] = [.vesting, .staking, .democracy]

    var displayType: LocalizableResource<String> {
        LocalizableResource<String> { locale in
            switch self {
            case .vesting:
                return R.string.localizable.walletAccountLocksVesting(
                    preferredLanguages: locale.rLanguages
                )
            case .staking:
                return R.string.localizable.stakingTitle(
                    preferredLanguages: locale.rLanguages
                )
            case .democracy:
                return R.string.localizable.walletAccountLocksDemocracy(
                    preferredLanguages: locale.rLanguages
                )
            }
        }
    }
}
