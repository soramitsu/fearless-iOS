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
        XCTAssertTrue(ScamInfo.ScamType.theft.isScam)
    }

    /// A stored flag this build does not know must not fail every stored flag.
    func testStoredFlagFromANewerBuildReadsAsUnknown() throws {
        let decoded = try JSONDecoder().decode(
            [ScamInfo].self,
            from: Data("""
            [{"name": "A", "address": "1a", "type": "a future category", "subtype": ""},
             {"name": "B", "address": "1b", "type": "High Risk Organization", "subtype": ""}]
            """.utf8)
        )
        XCTAssertEqual(decoded.map(\.type), [.unknown, .highRiskOrganization])
    }

    /// Rows the old parser stored are replaced by the next sync, and a bad download keeps every stored flag.
    func testSyncReplacesRowsTheOldParserStoredAndKeepsFlagsWhenTheListIsEmpty() throws {
        let phishing = "1Rb2Uhkkztfz2oJewKXcEBRykQurtJAZ1zLEsWyrFs24RFD"
        let local = [
            ScamInfo(name: "\"Polkadot2022 Net", address: " Polkadotevent2022\"", type: .unknown, subtype: "Scam"),
            ScamInfo(name: "Example custody", address: "1service", type: .unknown, subtype: "Custody"),
            ScamInfo(name: "Dot4 Org", address: "1scam", type: .scam, subtype: "Phishing")
        ]
        let remote = ScamSyncService.scamInfos(fromCsv: [
            "tag_name_verbose,addresses,tag_type_verbose,tag_subtype_verbose",
            "\"Polkadot2022 Net, Polkadotevent2022\",\(phishing),Scam,Phishing",
            "Example custody,1service,Service,Custody",
            "Dot4 Org,1scam,Scam,Phishing"
        ].joined(separator: "\r"))

        let changes = try XCTUnwrap(ScamSyncService.syncChanges(remote: remote, local: local))
        XCTAssertEqual(
            Set(changes.newOrUpdatedItems.map { "\($0.address) \($0.type)" }),
            ["\(phishing) scam", "1service service"]
        )
        XCTAssertEqual(changes.removedItems.map(\.address), [" Polkadotevent2022\""])

        XCTAssertNil(ScamSyncService.syncChanges(remote: [], local: local))
        XCTAssertNil(ScamSyncService.syncChanges(
            remote: ScamSyncService.scamInfos(fromCsv: "404: Not Found"),
            local: local
        ))
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
