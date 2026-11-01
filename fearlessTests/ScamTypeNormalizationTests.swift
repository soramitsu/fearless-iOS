import XCTest
@testable import fearless

final class ScamTypeNormalizationTests: XCTestCase {
    func testKnownCsvTypesNormalizeWhitespaceAndCase() {
        XCTAssertEqual(ScamInfo.ScamType(from: "Low network activity"), .lowScore)
        XCTAssertEqual(ScamInfo.ScamType(from: " LOW NETWORK ACTIVITY\n"), .lowScore)
        XCTAssertEqual(ScamInfo.ScamType(from: " SCAM "), .scam)
        XCTAssertEqual(ScamInfo.ScamType(from: "sanctions"), .sanctions)
        XCTAssertNil(ScamInfo.ScamType(from: "not-a-type"))
        XCTAssertNil(ScamInfo.ScamType(from: ""))
    }

    func testEveryCategoryOfTheScamListHasItsOwnType() {
        XCTAssertEqual(ScamInfo.ScamType(from: "Exchange"), .exchange)
        XCTAssertEqual(ScamInfo.ScamType(from: "Donation"), .donation)
        XCTAssertEqual(ScamInfo.ScamType(from: "Service"), .service)
        XCTAssertEqual(ScamInfo.ScamType(from: "High Risk Organization"), .highRiskOrganization)
        XCTAssertEqual(ScamInfo.ScamType(from: "Theft"), .theft)
    }

    /// Splitting each row on every comma stored this phishing address under the name's second half.
    func testQuotedNameWithACommaKeepsTheAddressAndTheFlag() {
        let infos = ScamSyncService.scamInfos(fromCsv: [
            "tag_name_verbose,addresses,tag_type_verbose,tag_subtype_verbose",
            "\"Polkadot2022 Net, Polkadotevent2022\",1Rb2Uhkkztfz2oJewKXcEBRykQurtJAZ1zLEsWyrFs24RFD,Scam,Phishing",
            "Example custody,1service,Service,Custody\r",
            "\"Say \"\"hi\"\"\",1theft,Theft,Hack",
            ""
        ].joined(separator: "\n"))
        let byAddress = Dictionary(uniqueKeysWithValues: infos.map { ($0.address, $0) })

        XCTAssertEqual(Set(byAddress.keys), ["1Rb2Uhkkztfz2oJewKXcEBRykQurtJAZ1zLEsWyrFs24RFD", "1service", "1theft"])
        XCTAssertEqual(
            byAddress["1Rb2Uhkkztfz2oJewKXcEBRykQurtJAZ1zLEsWyrFs24RFD"]?.name,
            "Polkadot2022 Net, Polkadotevent2022"
        )
        XCTAssertEqual(byAddress["1Rb2Uhkkztfz2oJewKXcEBRykQurtJAZ1zLEsWyrFs24RFD"]?.type, .scam)
        XCTAssertEqual(byAddress["1service"]?.type, .service)
        XCTAssertEqual(byAddress["1service"]?.subtype, "Custody")
        XCTAssertEqual(byAddress["1theft"]?.name, "Say \"hi\"")
        XCTAssertEqual(byAddress["1theft"]?.type, .theft)
    }

    /// The app downloads this list from master, which has the same copy.
    func testProductionScamListHasNoUnrecognisedCategory() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let csv = try String(
            contentsOf: repoRoot.appendingPathComponent(
                "remote-config/production/scamDetection/Polkadot_Hot_Wallet_Attributions.csv"
            ),
            encoding: .utf8
        )
        let infos = ScamSyncService.scamInfos(fromCsv: csv)

        XCTAssertGreaterThan(infos.count, 24000)
        XCTAssertEqual(infos.filter { $0.type == .unknown }.map(\.name), [])
        XCTAssertEqual(
            Set(infos.map(\.type)),
            [.exchange, .scam, .donation, .sanctions, .service, .highRiskOrganization, .theft]
        )
        XCTAssertEqual(infos.filter { $0.address.contains { " \",".contains($0) } }.map(\.address), [])
        XCTAssertEqual(
            infos.first { $0.address == "1Rb2Uhkkztfz2oJewKXcEBRykQurtJAZ1zLEsWyrFs24RFD" }?.type,
            .scam
        )
    }
}
