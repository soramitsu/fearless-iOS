import Foundation
@testable import fearless
import FearlessUtils
import IrohaCrypto
import BigInt

struct StakingRebondMock {
    static func addNomination(
        to stub: SingleValueProviderFactoryStub,
        address: AccountAddress
    ) throws -> SingleValueProviderFactoryStub {
        let accountId = try SS58AddressFactory().accountId(from: address)

        let unlockEra = WestendStub.activeEra.item.map({ $0.index + 1}) ?? 0
        let unlockChunk = UnlockChunk(value: BigUInt(1e+12), era: unlockEra)
        let ledgerInfo = StakingLedger(stash: accountId,
                                   total: BigUInt(2e+12),
                                   active: BigUInt(1e+12),
                                   unlocking: [unlockChunk],
                                   claimedRewards: [])

        return stub.with(ledger: ledgerInfo, for: address)
    }
}
