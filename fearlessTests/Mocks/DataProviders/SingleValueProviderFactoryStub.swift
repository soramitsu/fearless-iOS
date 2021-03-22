import Foundation
@testable import fearless
import RobinHood

final class SingleValueProviderFactoryStub: SingleValueProviderFactoryProtocol {
    let price: AnySingleValueProvider<PriceData>
    let totalReward: AnySingleValueProvider<TotalRewardItem>
    let balance: AnyDataProvider<DecodedAccountInfo>
    let electionStatus: AnyDataProvider<DecodedElectionStatus>
    let nomination: AnyDataProvider<DecodedNomination>
    let validatorPrefs: AnyDataProvider<DecodedValidator>
    let ledgerInfo: AnyDataProvider<DecodedLedgerInfo>
    let activeEra: AnyDataProvider<DecodedActiveEra>

    init(price: AnySingleValueProvider<PriceData>,
         totalReward: AnySingleValueProvider<TotalRewardItem>,
         balance: AnyDataProvider<DecodedAccountInfo>,
         electionStatus: AnyDataProvider<DecodedElectionStatus>,
         nomination: AnyDataProvider<DecodedNomination>,
         validatorPrefs: AnyDataProvider<DecodedValidator>,
         ledgerInfo: AnyDataProvider<DecodedLedgerInfo>,
         activeEra: AnyDataProvider<DecodedActiveEra>) {
        self.price = price
        self.totalReward = totalReward
        self.balance = balance
        self.electionStatus = electionStatus
        self.nomination = nomination
        self.validatorPrefs = validatorPrefs
        self.ledgerInfo = ledgerInfo
        self.activeEra = activeEra
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

        return SingleValueProviderFactoryStub(price: AnySingleValueProvider(priceProvider),
                                              totalReward: AnySingleValueProvider(totalRewardProvider),
                                              balance: AnyDataProvider(balanceProvider),
                                              electionStatus: AnyDataProvider(electionStatusProvider),
                                              nomination: AnyDataProvider(nominationProvider),
                                              validatorPrefs: AnyDataProvider(validatorProvider),
                                              ledgerInfo: AnyDataProvider(ledgerProvider),
                                              activeEra: AnyDataProvider(activeEra))
    }
}
