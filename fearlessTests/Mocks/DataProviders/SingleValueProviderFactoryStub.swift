import Foundation
@testable import fearless
import RobinHood
import IrohaCrypto
import BigInt
import FearlessUtils

final class SingleValueProviderFactoryStub: SingleValueProviderFactoryProtocol {
    let price: AnySingleValueProvider<PriceData>
    let totalReward: AnySingleValueProvider<TotalRewardItem>
    let balance: AnyDataProvider<DecodedAccountInfo>
    let nomination: AnyDataProvider<DecodedNomination>
    let validatorPrefs: AnyDataProvider<DecodedValidator>
    let ledgerInfo: AnyDataProvider<DecodedLedgerInfo>
    let activeEra: AnyDataProvider<DecodedActiveEra>
    let currentEra: AnyDataProvider<DecodedEraIndex>
    let payee: AnyDataProvider<DecodedPayee>
    let blockNumber: AnyDataProvider<DecodedBlockNumber>
    let crowdloanFunds: AnyDataProvider<DecodedCrowdloanFunds>
    let minNominatorBond: AnyDataProvider<DecodedBigUInt>
    let counterForNominators: AnyDataProvider<DecodedU32>
    let maxNominatorsCount: AnyDataProvider<DecodedU32>
    let jsonProviders: [URL: Any]
    let balanceLocks: AnyDataProvider<DecodedBalanceLocks>

    init(price: AnySingleValueProvider<PriceData>,
         totalReward: AnySingleValueProvider<TotalRewardItem>,
         balance: AnyDataProvider<DecodedAccountInfo>,
         nomination: AnyDataProvider<DecodedNomination>,
         validatorPrefs: AnyDataProvider<DecodedValidator>,
         ledgerInfo: AnyDataProvider<DecodedLedgerInfo>,
         activeEra: AnyDataProvider<DecodedActiveEra>,
         currentEra: AnyDataProvider<DecodedEraIndex>,
         payee: AnyDataProvider<DecodedPayee>,
         blockNumber: AnyDataProvider<DecodedBlockNumber>,
         minNominatorBond: AnyDataProvider<DecodedBigUInt>,
         counterForNominators: AnyDataProvider<DecodedU32>,
         maxNominatorsCount: AnyDataProvider<DecodedU32>,
         jsonProviders: [URL: Any] = [:],
         crowdloanFunds: AnyDataProvider<DecodedCrowdloanFunds>,
         balanceLocks: AnyDataProvider<DecodedBalanceLocks>) {
        self.price = price
        self.totalReward = totalReward
        self.balance = balance
        self.nomination = nomination
        self.validatorPrefs = validatorPrefs
        self.ledgerInfo = ledgerInfo
        self.activeEra = activeEra
        self.currentEra = currentEra
        self.payee = payee
        self.blockNumber = blockNumber
        self.minNominatorBond = minNominatorBond
        self.counterForNominators = counterForNominators
        self.maxNominatorsCount = maxNominatorsCount
        self.jsonProviders = jsonProviders
        self.crowdloanFunds = crowdloanFunds
        self.balanceLocks = balanceLocks
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

    func getCurrentEra(
        for chain: Chain,
        runtimeService: RuntimeCodingServiceProtocol
    ) throws -> AnyDataProvider<DecodedEraIndex> {
        currentEra
    }

    func getPayee(for address: String,
                  runtimeService: RuntimeCodingServiceProtocol) throws -> AnyDataProvider<DecodedPayee> {
        payee
    }

    func getMinNominatorBondProvider(
        chain: Chain,
        runtimeService: RuntimeCodingServiceProtocol
    ) throws -> AnyDataProvider<DecodedBigUInt> {
        minNominatorBond
    }

    func getCounterForNominatorsProvider(
        chain: Chain,
        runtimeService: RuntimeCodingServiceProtocol
    ) throws -> AnyDataProvider<DecodedU32> {
        counterForNominators
    }

    func getMaxNominatorsCountProvider(
        chain: Chain,
        runtimeService: RuntimeCodingServiceProtocol
    ) throws -> AnyDataProvider<DecodedU32> {
        maxNominatorsCount
    }

    func getBlockNumber(
        for chain: Chain,
        runtimeService: RuntimeCodingServiceProtocol
    ) throws -> AnyDataProvider<DecodedBlockNumber> {
        blockNumber
    }

    func getJson<T>(for url: URL) -> AnySingleValueProvider<T> where T : Decodable, T : Encodable, T : Equatable {
        guard let provider = jsonProviders[url] as? AnySingleValueProvider<T> else {
            let singleValueProviderStub = SingleValueProviderStub<T>(item: nil)
            return AnySingleValueProvider(singleValueProviderStub)
        }

        return provider
    }

    func getCrowdloanFunds(
        for paraId: ParaId,
        connection: ConnectionItem,
        engine: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> AnyDataProvider<DecodedCrowdloanFunds> {
        crowdloanFunds
    }

    func getBalanceLocks(for address: String, runtimeService: RuntimeCodingServiceProtocol) throws
    -> AnyDataProvider<DecodedBalanceLocks> {
        balanceLocks
    }
}

extension SingleValueProviderFactoryStub {
    static func westendNominatorStub() -> SingleValueProviderFactoryStub {
        let priceProvider = SingleValueProviderStub(item: WestendStub.price)
        let totalRewardProvider = SingleValueProviderStub(item: WestendStub.totalReward)
        let balanceProvider = DataProviderStub(models: [WestendStub.accountInfo])
        let nominationProvider = DataProviderStub(models: [WestendStub.nomination])
        let validatorProvider = DataProviderStub<DecodedValidator>(models: [])
        let ledgerProvider = DataProviderStub(models: [WestendStub.ledgerInfo])
        let activeEra = DataProviderStub(models: [WestendStub.activeEra])
        let currentEra = DataProviderStub(models: [WestendStub.currentEra])
        let minNominatorBond = DataProviderStub(models: [WestendStub.minNominatorBond])
        let counterForNominators = DataProviderStub(models: [WestendStub.counterForNominators])
        let maxNominatorsCount = DataProviderStub(models: [WestendStub.maxNominatorsCount])

        let payeeId = (WestendStub.ledgerInfo.item?.stash.toHex() ?? "") + "_payee"
        let decodedPayee = DecodedPayee(identifier: payeeId, item: .staked)
        let payee = DataProviderStub(models: [decodedPayee])
        let blockNumber = DataProviderStub<DecodedBlockNumber>(models: [])
        let crowdloanFunds = DataProviderStub<DecodedCrowdloanFunds>(models: [])
        let balanceLocks = DataProviderStub<DecodedBalanceLocks>(models: [])

        return SingleValueProviderFactoryStub(price: AnySingleValueProvider(priceProvider),
                                              totalReward: AnySingleValueProvider(totalRewardProvider),
                                              balance: AnyDataProvider(balanceProvider),
                                              nomination: AnyDataProvider(nominationProvider),
                                              validatorPrefs: AnyDataProvider(validatorProvider),
                                              ledgerInfo: AnyDataProvider(ledgerProvider),
                                              activeEra: AnyDataProvider(activeEra),
                                              currentEra: AnyDataProvider(currentEra),
                                              payee: AnyDataProvider(payee),
                                              blockNumber: AnyDataProvider(blockNumber),
                                              minNominatorBond: AnyDataProvider(minNominatorBond),
                                              counterForNominators: AnyDataProvider(counterForNominators),
                                              maxNominatorsCount: AnyDataProvider(maxNominatorsCount),
                                              crowdloanFunds: AnyDataProvider(crowdloanFunds),
                                              balanceLocks: AnyDataProvider(balanceLocks)
                                              )
    }

    func with(
        ledger: StakingLedger,
        for address: AccountAddress
    ) -> SingleValueProviderFactoryStub {
        let decodedLedger = DecodedLedgerInfo(
            identifier: address,
            item: ledger
        )

        let ledgerProviderStub = DataProviderStub(models: [decodedLedger])

        return SingleValueProviderFactoryStub(price: price,
                                              totalReward: totalReward,
                                              balance: balance,
                                              nomination: nomination,
                                              validatorPrefs: validatorPrefs,
                                              ledgerInfo: AnyDataProvider(ledgerProviderStub),
                                              activeEra: activeEra,
                                              currentEra: currentEra,
                                              payee: payee,
                                              blockNumber: blockNumber,
                                              minNominatorBond: minNominatorBond,
                                              counterForNominators: counterForNominators,
                                              maxNominatorsCount: maxNominatorsCount,
                                              jsonProviders: jsonProviders,
                                              crowdloanFunds: crowdloanFunds,
                                              balanceLocks: balanceLocks)
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
                                              nomination: AnyDataProvider(nominationProvider),
                                              validatorPrefs: validatorPrefs,
                                              ledgerInfo: ledgerInfo,
                                              activeEra: activeEra,
                                              currentEra: currentEra,
                                              payee: payee,
                                              blockNumber: blockNumber,
                                              minNominatorBond: minNominatorBond,
                                              counterForNominators: counterForNominators,
                                              maxNominatorsCount: maxNominatorsCount,
                                              jsonProviders: jsonProviders,
                                              crowdloanFunds: crowdloanFunds,
                                              balanceLocks: balanceLocks)
    }

    func withBlockNumber(
        blockNumber: BlockNumber
    ) -> SingleValueProviderFactoryStub {
        let decodedBlockNumber = DecodedBlockNumber(
            identifier: "block_number",
            item: StringScaleMapper(value: blockNumber)
        )

        let blockProvider = DataProviderStub(models: [decodedBlockNumber])
        return SingleValueProviderFactoryStub(price: price,
                                              totalReward: totalReward,
                                              balance: balance,
                                              nomination: nomination,
                                              validatorPrefs: validatorPrefs,
                                              ledgerInfo: ledgerInfo,
                                              activeEra: activeEra,
                                              currentEra: currentEra,
                                              payee: payee,
                                              blockNumber: AnyDataProvider(blockProvider),
                                              minNominatorBond: minNominatorBond,
                                              counterForNominators: counterForNominators,
                                              maxNominatorsCount: maxNominatorsCount,
                                              jsonProviders: jsonProviders,
                                              crowdloanFunds: crowdloanFunds,
                                              balanceLocks: balanceLocks)
    }

    func withJSON<T>(
        value: T,
        for url: URL
    ) -> SingleValueProviderFactoryStub where T : Decodable, T : Encodable, T : Equatable {

        let singleValueProvider = SingleValueProviderStub(item: value)

        var currentProviders = jsonProviders
        currentProviders[url] = AnySingleValueProvider(singleValueProvider)

        return SingleValueProviderFactoryStub(
            price: price,
            totalReward: totalReward,
            balance: balance,
            nomination: nomination,
            validatorPrefs: validatorPrefs,
            ledgerInfo: ledgerInfo,
            activeEra: activeEra,
            currentEra: currentEra,
            payee: payee,
            blockNumber: blockNumber,
            minNominatorBond: minNominatorBond,
            counterForNominators: counterForNominators,
            maxNominatorsCount: maxNominatorsCount,
            jsonProviders: currentProviders,
            crowdloanFunds: crowdloanFunds,
            balanceLocks: balanceLocks
        )
    }

    func withCrowdloanFunds(
        _ funds: CrowdloanFunds
    ) -> SingleValueProviderFactoryStub {
        let decodedCrowdloan = DecodedCrowdloanFunds(
            identifier: funds.depositor.toHex(),
            item: funds
        )
        let dataProvider = DataProviderStub(models: [decodedCrowdloan])

        return SingleValueProviderFactoryStub(
            price: price,
            totalReward: totalReward,
            balance: balance,
            nomination: nomination,
            validatorPrefs: validatorPrefs,
            ledgerInfo: ledgerInfo,
            activeEra: activeEra,
            currentEra: currentEra,
            payee: payee,
            blockNumber: blockNumber,
            minNominatorBond: minNominatorBond,
            counterForNominators: counterForNominators,
            maxNominatorsCount: maxNominatorsCount,
            jsonProviders: jsonProviders,
            crowdloanFunds: AnyDataProvider(dataProvider),
            balanceLocks: balanceLocks
        )
    }

    func withBalanceLocks(
        _ locks: BalanceLocks
    ) -> SingleValueProviderFactoryStub {

        let decodedBalanceLocks: [DecodedBalanceLocks] = locks.compactMap { lock in
            guard let identifier = lock.displayId else { return nil }

            return DecodedBalanceLocks(
                identifier: identifier,
                item: lock
            )
        }

        let dataProvider = DataProviderStub(models: decodedBalanceLocks)

        return SingleValueProviderFactoryStub(
            price: price,
            totalReward: totalReward,
            balance: balance,
            nomination: nomination,
            validatorPrefs: validatorPrefs,
            ledgerInfo: ledgerInfo,
            activeEra: activeEra,
            currentEra: currentEra,
            payee: payee,
            blockNumber: blockNumber,
            minNominatorBond: minNominatorBond,
            counterForNominators: counterForNominators,
            maxNominatorsCount: maxNominatorsCount,
            jsonProviders: jsonProviders,
            crowdloanFunds: crowdloanFunds,
            balanceLocks: AnyDataProvider(dataProvider)
        )
    }
}
