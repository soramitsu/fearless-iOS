import Foundation
@testable import fearless
import RobinHood
import IrohaCrypto
import BigInt

final class SingleValueProviderFactoryStub: SingleValueProviderFactoryProtocol {
    let price: AnySingleValueProvider<PriceData>
    let totalReward: AnySingleValueProvider<TotalRewardItem>
    let balance: AnyDataProvider<DecodedAccountInfo>
    let electionStatus: AnyDataProvider<DecodedElectionStatus>
    let nomination: AnyDataProvider<DecodedNomination>
    let validatorPrefs: AnyDataProvider<DecodedValidator>
    let ledgerInfo: AnyDataProvider<DecodedLedgerInfo>
    let activeEra: AnyDataProvider<DecodedActiveEra>
    let payee: AnyDataProvider<DecodedPayee>

    init(price: AnySingleValueProvider<PriceData>,
         totalReward: AnySingleValueProvider<TotalRewardItem>,
         balance: AnyDataProvider<DecodedAccountInfo>,
         electionStatus: AnyDataProvider<DecodedElectionStatus>,
         nomination: AnyDataProvider<DecodedNomination>,
         validatorPrefs: AnyDataProvider<DecodedValidator>,
         ledgerInfo: AnyDataProvider<DecodedLedgerInfo>,
         activeEra: AnyDataProvider<DecodedActiveEra>,
         payee: AnyDataProvider<DecodedPayee>) {
        self.price = price
        self.totalReward = totalReward
        self.balance = balance
        self.electionStatus = electionStatus
        self.nomination = nomination
        self.validatorPrefs = validatorPrefs
        self.ledgerInfo = ledgerInfo
        self.activeEra = activeEra
        self.payee = payee
    }

    func getPriceProvider(for assetId: WalletAssetId) -> AnySingleValueProvider<PriceData> {
        price
    }

    func getTotalReward(for address: String,
                        assetId: WalletAssetId) throws -> AnySingleValueProvider<TotalRewardItem> {
        totalReward
    }

    func getAccountProvider(for address: String, runtimeService: RuntimeCodingServiceProtocol) throws
    -> AnyDataProvider<DecodedAccountInfo> {
        balance
    }

    func getElectionStatusProvider(chain: Chain, runtimeService: RuntimeCodingServiceProtocol) throws -> AnyDataProvider<DecodedElectionStatus> {
        electionStatus
    }

    func getNominationProvider(for address: String, runtimeService: RuntimeCodingServiceProtocol) throws -> AnyDataProvider<DecodedNomination> {
        nomination
    }

    func getValidatorProvider(for address: String, runtimeService: RuntimeCodingServiceProtocol) throws -> AnyDataProvider<DecodedValidator> {
        validatorPrefs
    }

    func getLedgerInfoProvider(for address: String,
                               runtimeService: RuntimeCodingServiceProtocol) throws
    -> AnyDataProvider<DecodedLedgerInfo> {
        ledgerInfo
    }

    func getActiveEra(for chain: Chain,
                      runtimeService: RuntimeCodingServiceProtocol) throws
    -> AnyDataProvider<DecodedActiveEra> {
        activeEra
    }

    func getPayee(for address: String,
                  runtimeService: RuntimeCodingServiceProtocol) throws -> AnyDataProvider<DecodedPayee> {
        payee
    }
}

extension SingleValueProviderFactoryStub {
    static func westendNominatorStub() -> SingleValueProviderFactoryStub {
        let priceProvider = SingleValueProviderStub(item: WestendStub.price)
        let totalRewardProvider = SingleValueProviderStub(item: WestendStub.totalReward)
        let balanceProvider = DataProviderStub(models: [WestendStub.accountInfo])
        let electionStatusProvider = DataProviderStub(models: [WestendStub.electionStatus])
        let nominationProvider = DataProviderStub(models: [WestendStub.nomination])
        let validatorProvider = DataProviderStub<DecodedValidator>(models: [])
        let ledgerProvider = DataProviderStub(models: [WestendStub.ledgerInfo])
        let activeEra = DataProviderStub(models: [WestendStub.activeEra])

        let payeeId = (WestendStub.ledgerInfo.item?.stash.toHex() ?? "") + "_payee"
        let decodedPayee = DecodedPayee(identifier: payeeId, item: .staked)
        let payee = DataProviderStub(models: [decodedPayee])

        return SingleValueProviderFactoryStub(price: AnySingleValueProvider(priceProvider),
                                              totalReward: AnySingleValueProvider(totalRewardProvider),
                                              balance: AnyDataProvider(balanceProvider),
                                              electionStatus: AnyDataProvider(electionStatusProvider),
                                              nomination: AnyDataProvider(nominationProvider),
                                              validatorPrefs: AnyDataProvider(validatorProvider),
                                              ledgerInfo: AnyDataProvider(ledgerProvider),
                                              activeEra: AnyDataProvider(activeEra),
                                              payee: AnyDataProvider(payee))
    }

    static func nonEmptyRedeemingStub(for address: AccountAddress) -> SingleValueProviderFactoryStub {
        let priceProvider = SingleValueProviderStub(item: WestendStub.price)
        let totalRewardProvider = SingleValueProviderStub(item: WestendStub.totalReward)
        let balanceProvider = DataProviderStub(models: [WestendStub.accountInfo])
        let electionStatusProvider = DataProviderStub(models: [WestendStub.electionStatus])
        let nominationProvider = DataProviderStub(models: [WestendStub.nomination])
        let validatorProvider = DataProviderStub<DecodedValidator>(models: [])

        let accountId = try! SS58AddressFactory().accountId(from: address)

        let unlockEra = WestendStub.activeEra.item.map({ $0.index - 1}) ?? 0
        let unlockChunk = DyUnlockChunk(value: BigUInt(1e+12), era: unlockEra)
        let ledgerInfo = DyStakingLedger(stash: accountId,
                                   total: BigUInt(2e+12),
                                   active: BigUInt(1e+12),
                                   unlocking: [unlockChunk],
                                   claimedRewards: [])

        let decodedStakingLedger = DecodedLedgerInfo(identifier: address, item: ledgerInfo)
        let ledgerProvider = DataProviderStub(models: [decodedStakingLedger])
        let activeEra = DataProviderStub(models: [WestendStub.activeEra])

        let payeeId = (WestendStub.ledgerInfo.item?.stash.toHex() ?? "") + "_payee"
        let decodedPayee = DecodedPayee(identifier: payeeId, item: .staked)
        let payee = DataProviderStub(models: [decodedPayee])

        return SingleValueProviderFactoryStub(price: AnySingleValueProvider(priceProvider),
                                              totalReward: AnySingleValueProvider(totalRewardProvider),
                                              balance: AnyDataProvider(balanceProvider),
                                              electionStatus: AnyDataProvider(electionStatusProvider),
                                              nomination: AnyDataProvider(nominationProvider),
                                              validatorPrefs: AnyDataProvider(validatorProvider),
                                              ledgerInfo: AnyDataProvider(ledgerProvider),
                                              activeEra: AnyDataProvider(activeEra),
                                              payee: AnyDataProvider(payee))
    }

    func with(
        nomination: Nomination,
        for address: AccountAddress
    ) -> SingleValueProviderFactoryStub {
        let decodedNomination = DecodedNomination(
            identifier: address,
            item: nomination
        )
        let nominationProvider = DataProviderStub(models: [decodedNomination])
        return SingleValueProviderFactoryStub(price: price,
                                              totalReward: totalReward,
                                              balance: balance,
                                              electionStatus: electionStatus,
                                              nomination: AnyDataProvider(nominationProvider),
                                              validatorPrefs: validatorPrefs,
                                              ledgerInfo: ledgerInfo,
                                              activeEra: activeEra,
                                              payee: payee)
    }
}
