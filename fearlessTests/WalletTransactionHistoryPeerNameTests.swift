import SSFModels
import SSFUtils
import XCTest
@testable import fearless

/// A transfer whose peer has a name shows that name in the history list. The list used the CommonWallet key
/// `common.full_name`, which no Localizable.strings defined, so the row read "common.full_name".
final class WalletTransactionHistoryPeerNameTests: XCTestCase {
    func testTransferShowsThePeersFirstAndLastName() throws {
        let row = try historyRow(firstName: "Alice", lastName: "Smith")
        XCTAssertEqual(row.address, "Alice Smith")
    }

    func testTransferWithOnlyAFirstNameShowsItWithoutTrailingSpace() throws {
        let row = try historyRow(firstName: "Alice", lastName: nil)
        XCTAssertEqual(row.address, "Alice")
    }

    func testEveryShippedLocalizationDefinesTheFullNameFormat() throws {
        let bundle = Bundle(for: WalletTransactionHistoryViewModelFactory.self)
        let localizations = bundle.localizations.filter { $0 != "Base" }
        XCTAssertFalse(localizations.isEmpty)
        for localization in localizations {
            let path = try XCTUnwrap(bundle.path(forResource: localization, ofType: "lproj"), localization)
            let languageBundle = try XCTUnwrap(Bundle(path: path), localization)
            let format = languageBundle.localizedString(forKey: "common.full_name", value: nil, table: "Localizable")
            XCTAssertEqual(String(format: format, "A", "B"), "A B", "\(localization) formats a first and last name")
        }
    }

    private func historyRow(firstName: String?, lastName: String?) throws -> WalletTransactionHistoryCellViewModel {
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let asset = ChainModelGenerator.generateAssetWithId("dot", symbol: "DOT", assetPresicion: 10)
        let factory = WalletTransactionHistoryViewModelFactory(
            balanceFormatterFactory: AssetBalanceFormatterFactory(),
            includesFeeInAmount: false,
            transactionTypes: [],
            chainAsset: ChainAsset(chain: chain, asset: asset),
            iconGenerator: UniversalIconGenerator()
        )
        let transfer = AssetTransactionData(
            transactionId: "0x01",
            status: .commited,
            assetId: asset.id,
            peerId: "peer",
            peerFirstName: firstName,
            peerLastName: lastName,
            peerName: "fallback",
            details: "",
            amount: AmountDecimal(value: 1),
            fees: [],
            timestamp: 1_700_000_000,
            type: TransactionType.incoming.rawValue,
            reason: nil,
            context: nil
        )
        var sections: [WalletTransactionHistorySection] = []
        _ = try factory.merge(newItems: [transfer], into: &sections, locale: Locale(identifier: "en_US"))
        return try XCTUnwrap(sections.first?.items.first)
    }
}
