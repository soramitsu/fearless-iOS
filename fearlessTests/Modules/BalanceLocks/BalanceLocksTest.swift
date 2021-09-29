import XCTest
@testable import fearless

class BalanceLocksTest: XCTestCase {
    func testLocksRestoration() throws {

        // given
        let context = ["account.balance.price.change.key": "0",
                       "account.balance.fee.frozen.key": "2.3657237",
                       "account.balance.locks.key":"[{\"id\":[\"115\",\"116\",\"97\",\"107\",\"105\",\"110\",\"103\",\"32\"],\"amount\":\"2365723700000\",\"reasons\":2}]",
                       "account.balance.reserved.key": "1.00205",
                       "account.balance.misc.frozen.key": "2.3657237",
                       "account.balance.price.key": "0",
                       "account.balance.minimal.key": "0.01",
                       "account.balance.free.key": "5.06791402788"]

        // when

        let balanceContext = BalanceContext.init(context: context)

        // then

        XCTAssertEqual(balanceContext.balanceLocks.count, 1)
    }

    func testMainLocksSeparation() throws {
        // given
        let context = ["account.balance.price.change.key": "0",
                       "account.balance.fee.frozen.key": "2.3657237",
                       "account.balance.locks.key":"[{\"id\":[\"115\",\"116\",\"97\",\"107\",\"105\",\"110\",\"103\",\"32\"],\"amount\":\"2365723700000\",\"reasons\":2},{\"id\":[\"115\",\"116\",\"97\",\"115\",\"105\",\"110\",\"103\",\"32\"],\"amount\":\"2365723700000\",\"reasons\":2}]",
                       "account.balance.reserved.key": "1.00205",
                       "account.balance.misc.frozen.key": "2.3657237",
                       "account.balance.price.key": "0",
                       "account.balance.minimal.key": "0.01",
                       "account.balance.free.key": "5.06791402788"]

        // when

        let balanceContext = BalanceContext.init(context: context)
        let mainLocks = balanceContext.balanceLocks.mainLocks()

        // then

        XCTAssertEqual(mainLocks.count, 1)

        XCTAssertEqual(LockType(rawValue: mainLocks.first?.displayId ?? ""), .staking)
    }

    func testAuxLocksSeparation() throws {
        // given
        let context = ["account.balance.price.change.key": "0",
                       "account.balance.fee.frozen.key": "2.3657237",
                       "account.balance.locks.key":"[{\"id\":[\"115\",\"116\",\"97\",\"107\",\"105\",\"110\",\"103\",\"32\"],\"amount\":\"2365723700000\",\"reasons\":2},{\"id\":[\"115\",\"116\",\"97\",\"115\",\"105\",\"110\",\"103\",\"32\"],\"amount\":\"2365723700000\",\"reasons\":2}]",
                       "account.balance.reserved.key": "1.00205",
                       "account.balance.misc.frozen.key": "2.3657237",
                       "account.balance.price.key": "0",
                       "account.balance.minimal.key": "0.01",
                       "account.balance.free.key": "5.06791402788"]

        // when

        let balanceContext = BalanceContext.init(context: context)
        let auxLocks = balanceContext.balanceLocks.auxLocks()

        // then

        XCTAssertEqual(auxLocks.count, 1)

        XCTAssertEqual(auxLocks.first?.displayId, "stasing")
    }

    func testMainLocksOrder() throws {
        // given
        let context = ["account.balance.price.change.key": "0",
                       "account.balance.fee.frozen.key": "2.3657237",
                       "account.balance.locks.key":"[{\"id\":[\"115\",\"116\",\"97\",\"107\",\"105\",\"110\",\"103\",\"32\"],\"amount\":\"2365723700000\",\"reasons\":2},{\"id\":[\"118\",\"101\",\"115\",\"116\",\"105\",\"110\",\"103\",\"32\"],\"amount\":\"2365723700000\",\"reasons\":2}]",
                       "account.balance.reserved.key": "1.00205",
                       "account.balance.misc.frozen.key": "2.3657237",
                       "account.balance.price.key": "0",
                       "account.balance.minimal.key": "0.01",
                       "account.balance.free.key": "5.06791402788"]

        // when

        let balanceContext = BalanceContext.init(context: context)
        let mainLocks = balanceContext.balanceLocks.mainLocks()

        // then

        XCTAssertEqual(mainLocks.count, 2)

        XCTAssertEqual(LockType(rawValue: mainLocks.first?.displayId ?? ""), .vesting)
    }

    func testAuxLocksOrder() throws {
        // given
        let context = ["account.balance.price.change.key": "0",
                       "account.balance.fee.frozen.key": "2.3657237",
                       "account.balance.locks.key":"[{\"id\":[\"107\",\"105\",\"115\",\"115\",\"105\",\"110\",\"103\",\"32\"],\"amount\":\"2365723700000\",\"reasons\":2},{\"id\":[\"115\",\"116\",\"97\",\"115\",\"105\",\"110\",\"103\",\"32\"],\"amount\":\"2375723700000\",\"reasons\":2}]",
                       "account.balance.reserved.key": "1.00205",
                       "account.balance.misc.frozen.key": "2.3657237",
                       "account.balance.price.key": "0",
                       "account.balance.minimal.key": "0.01",
                       "account.balance.free.key": "5.06791402788"]

        // when

        let balanceContext = BalanceContext.init(context: context)
        let auxLocks = balanceContext.balanceLocks.auxLocks()

        // then

        XCTAssertEqual(auxLocks.count, 2)

        XCTAssertEqual(auxLocks.first?.displayId, "stasing")
    }
}
