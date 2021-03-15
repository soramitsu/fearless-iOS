import Foundation
@testable import fearless
import RobinHood

final class SingleValueProviderFactoryStub: SingleValueProviderFactoryProtocol {
    let price: AnySingleValueProvider<PriceData>
    let balance: AnyDataProvider<DecodedAccountInfo>
    let electionStatus: AnyDataProvider<DecodedElectionStatus>
    let nomination: AnyDataProvider<DecodedNomination>
    let validatorPrefs: AnyDataProvider<DecodedValidator>
    let ledgerInfo: AnyDataProvider<DecodedLedgerInfo>

    init(price: AnySingleValueProvider<PriceData>,
         balance: AnyDataProvider<DecodedAccountInfo>,
         electionStatus: AnyDataProvider<DecodedElectionStatus>,
         nomination: AnyDataProvider<DecodedNomination>,
         validatorPrefs: AnyDataProvider<DecodedValidator>,
         ledgerInfo: AnyDataProvider<DecodedLedgerInfo>) {
        self.price = price
        self.balance = balance
        self.electionStatus = electionStatus
        self.nomination = nomination
        self.validatorPrefs = validatorPrefs
        self.ledgerInfo = ledgerInfo
    }

    func getPriceProvider(for assetId: WalletAssetId) -> AnySingleValueProvider<PriceData> {
        price
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
}
