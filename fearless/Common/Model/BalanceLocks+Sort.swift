import Foundation

typealias BalanceLocks = [BalanceLock]

extension BalanceLocks {
    func vesting() -> BalanceLock? {
        first(where: { lock in
            lock.displayId == LockType.vesting.rawValue
        })
    }

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
