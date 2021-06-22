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
    let electionStatus: AnyDataProvider<DecodedElectionStatus>
    let nomination: AnyDataProvider<DecodedNomination>
    let validatorPrefs: AnyDataProvider<DecodedValidator>
    let ledgerInfo: AnyDataProvider<DecodedLedgerInfo>
    let activeEra: AnyDataProvider<DecodedActiveEra>
    let payee: AnyDataProvider<DecodedPayee>
    let blockNumber: AnyDataProvider<DecodedBlockNumber>
    let crowdloanFunds: AnyDataProvider<DecodedCrowdloanFunds>
    let minNominatorBond: AnyDataProvider<DecodedMinNominatorBond>
    let jsonProviders: [URL: Any]

    init(price: AnySingleValueProvider<PriceData>,
         totalReward: AnySingleValueProvider<TotalRewardItem>,
         balance: AnyDataProvider<DecodedAccountInfo>,
         electionStatus: AnyDataProvider<DecodedElectionStatus>,
         nomination: AnyDataProvider<DecodedNomination>,
         validatorPrefs: AnyDataProvider<DecodedValidator>,
         ledgerInfo: AnyDataProvider<DecodedLedgerInfo>,
         activeEra: AnyDataProvider<DecodedActiveEra>,
         payee: AnyDataProvider<DecodedPayee>,
         blockNumber: AnyDataProvider<DecodedBlockNumber>,
         minNominatorBond: AnyDataProvider<DecodedMinNominatorBond>,
         jsonProviders: [URL: Any] = [:],
         crowdloanFunds: AnyDataProvider<DecodedCrowdloanFunds>) {
        self.price = price
        self.totalReward = totalReward
        self.balance = balance
        self.electionStatus = electionStatus
        self.nomination = nomination
        self.validatorPrefs = validatorPrefs
        self.ledgerInfo = ledgerInfo
        self.activeEra = activeEra
        self.payee = payee
        self.blockNumber = blockNumber
        self.minNominatorBond = minNominatorBond
        self.jsonProviders = jsonProviders
        self.crowdloanFunds = crowdloanFunds
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

    func getMinNominatorBondProvider(
        chain: Chain,
        runtimeService: RuntimeCodingServiceProtocol
    ) throws -> AnyDataProvider<DecodedMinNominatorBond> {
        minNominatorBond
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
        let minNominatorBond = DataProviderStub(models: [WestendStub.minNominatorBond])

        let payeeId = (WestendStub.ledgerInfo.item?.stash.toHex() ?? "") + "_payee"
        let decodedPayee = DecodedPayee(identifier: payeeId, item: .staked)
        let payee = DataProviderStub(models: [decodedPayee])
        let blockNumber = DataProviderStub<DecodedBlockNumber>(models: [])
        let crowdloanFunds = DataProviderStub<DecodedCrowdloanFunds>(models: [])

        return SingleValueProviderFactoryStub(price: AnySingleValueProvider(priceProvider),
                                              totalReward: AnySingleValueProvider(totalRewardProvider),
                                              balance: AnyDataProvider(balanceProvider),
                                              electionStatus: AnyDataProvider(electionStatusProvider),
                                              nomination: AnyDataProvider(nominationProvider),
                                              validatorPrefs: AnyDataProvider(validatorProvider),
                                              ledgerInfo: AnyDataProvider(ledgerProvider),
                                              activeEra: AnyDataProvider(activeEra),
                                              payee: AnyDataProvider(payee),
                                              blockNumber: AnyDataProvider(blockNumber),
                                              minNominatorBond: AnyDataProvider(minNominatorBond),
                                              crowdloanFunds: AnyDataProvider(crowdloanFunds))
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
                                              electionStatus: electionStatus,
                                              nomination: nomination,
                                              validatorPrefs: validatorPrefs,
                                              ledgerInfo: AnyDataProvider(ledgerProviderStub),
                                              activeEra: activeEra,
                                              payee: payee,
                                              blockNumber: blockNumber,
                                              minNominatorBond: minNominatorBond,
                                              jsonProviders: jsonProviders,
                                              crowdloanFunds: crowdloanFunds)
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
                                              payee: payee,
                                              blockNumber: blockNumber,
                                              minNominatorBond: minNominatorBond,
                                              jsonProviders: jsonProviders,
                                              crowdloanFunds: crowdloanFunds)
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
                                              electionStatus: electionStatus,
                                              nomination: nomination,
                                              validatorPrefs: validatorPrefs,
                                              ledgerInfo: ledgerInfo,
                                              activeEra: activeEra,
                                              payee: payee,
                                              blockNumber: AnyDataProvider(blockProvider),
                                              minNominatorBond: minNominatorBond,
                                              jsonProviders: jsonProviders,
                                              crowdloanFunds: crowdloanFunds)
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
            electionStatus: electionStatus,
            nomination: nomination,
            validatorPrefs: validatorPrefs,
            ledgerInfo: ledgerInfo,
            activeEra: activeEra,
            payee: payee,
            blockNumber: blockNumber,
            minNominatorBond: minNominatorBond,
            jsonProviders: currentProviders,
            crowdloanFunds: crowdloanFunds
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
            electionStatus: electionStatus,
            nomination: nomination,
            validatorPrefs: validatorPrefs,
            ledgerInfo: ledgerInfo,
            activeEra: activeEra,
            payee: payee,
            blockNumber: blockNumber,
            minNominatorBond: minNominatorBond,
            jsonProviders: jsonProviders,
            crowdloanFunds: AnyDataProvider(dataProvider)
        )
    }
}
