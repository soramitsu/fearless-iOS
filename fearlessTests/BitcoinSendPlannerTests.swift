import XCTest
@testable import fearless

final class BitcoinSendPlannerTests: XCTestCase {
    func testPlansUnsignedSpendWithEstimatedFeeAndConfirmedUtxos() async throws {
        let client = FakeBitcoinIndexerClient(
            estimates: ["2": 2],
            utxosByAddress: [Self.mainnetAddress: [Self.utxo(valueSats: 100_000)]]
        )
        let planner = BitcoinSendPlanner(client: client)

        let plan = try await planner.plan(
            amountSats: 50_000,
            sources: [BitcoinUtxoSource(address: Self.mainnetAddress, derivationPath: "m/84'/0'/0'/0/0")],
            recipientAddress: Self.recipientAddress
        )

        XCTAssertEqual(plan.amountSats, 50_000)
        XCTAssertEqual(plan.recipientAddress, Self.recipientAddress)
        XCTAssertEqual(plan.changeAddress, Self.mainnetAddress)
        XCTAssertEqual(plan.feeRateSatPerVbyte, 2)
        XCTAssertEqual(plan.feeTargetBlocks, 2)
        XCTAssertEqual(plan.sourceAddresses, [Self.mainnetAddress])
        XCTAssertEqual(plan.selectedUtxos.count, 1)
        XCTAssertEqual(plan.feeSats, 282)
        XCTAssertEqual(plan.changeSats, 49_718)
        XCTAssertEqual(plan.absorbedDustSats, 0)
        XCTAssertEqual(client.feeEstimateNetworks, [.mainnet])
        XCTAssertEqual(client.utxoAddressCalls, [Self.mainnetAddress])
    }

    func testUsesManualFeeRateWithoutFetchingFeeEstimates() async throws {
        let client = FakeBitcoinIndexerClient(
            utxosByAddress: [Self.mainnetAddress: [Self.utxo(valueSats: 50_110)]]
        )
        let planner = BitcoinSendPlanner(client: client)

        let plan = try await planner.plan(
            amountSats: 50_000,
            sources: [BitcoinUtxoSource(address: Self.mainnetAddress)],
            recipientAddress: Self.recipientAddress,
            feeRateSatPerVbyte: 1
        )

        XCTAssertEqual(plan.feeRateSatPerVbyte, 1)
        XCTAssertNil(plan.feeTargetBlocks)
        XCTAssertEqual(plan.feeSats, 110)
        XCTAssertTrue(client.feeEstimateNetworks.isEmpty)
    }

    func testRequiresExplicitOptInForUnconfirmedUtxos() async throws {
        let client = FakeBitcoinIndexerClient(
            utxosByAddress: [Self.mainnetAddress: [Self.utxo(valueSats: 100_000, confirmed: false)]]
        )
        let planner = BitcoinSendPlanner(client: client)

        await assertPlannerError(.noSpendableUtxos) {
            _ = try await planner.plan(
                amountSats: 50_000,
                sources: [BitcoinUtxoSource(address: Self.mainnetAddress)],
                recipientAddress: Self.recipientAddress,
                feeRateSatPerVbyte: 1
            )
        }

        let plan = try await planner.plan(
            amountSats: 50_000,
            sources: [BitcoinUtxoSource(address: Self.mainnetAddress)],
            recipientAddress: Self.recipientAddress,
            feeRateSatPerVbyte: 1,
            includeUnconfirmed: true
        )

        XCTAssertTrue(plan.includeUnconfirmed)
        XCTAssertEqual(plan.selectedUtxos.count, 1)
    }

    func testRejectsInvalidPlannerInputsBeforeNetworkCalls() async {
        let client = FakeBitcoinIndexerClient()
        let planner = BitcoinSendPlanner(client: client)

        await assertPlannerError(.sourcesRequired) {
            _ = try await planner.plan(
                amountSats: 1_000,
                sources: [],
                recipientAddress: Self.recipientAddress,
                feeRateSatPerVbyte: 1
            )
        }
        await assertPlannerError(.tooManySources) {
            _ = try await planner.plan(
                amountSats: 1_000,
                sources: (0...100).map {
                    BitcoinUtxoSource(address: "bc1q\(String(format: "%03d", $0))aaaaaaaaaaaaaa")
                },
                recipientAddress: Self.recipientAddress,
                feeRateSatPerVbyte: 1
            )
        }
        await assertPlannerError(.invalidSourceAddress) {
            _ = try await planner.plan(
                amountSats: 1_000,
                sources: [BitcoinUtxoSource(address: Self.testnetAddress)],
                recipientAddress: Self.recipientAddress,
                feeRateSatPerVbyte: 1
            )
        }
        await assertPlannerError(.duplicateSourceAddress) {
            _ = try await planner.plan(
                amountSats: 1_000,
                sources: [
                    BitcoinUtxoSource(address: Self.mainnetAddress),
                    BitcoinUtxoSource(address: Self.mainnetAddress.uppercased())
                ],
                recipientAddress: Self.recipientAddress,
                feeRateSatPerVbyte: 1
            )
        }
        await assertPlannerError(.invalidDerivationPath) {
            _ = try await planner.plan(
                amountSats: 1_000,
                sources: [BitcoinUtxoSource(address: Self.mainnetAddress, derivationPath: "../bad")],
                recipientAddress: Self.recipientAddress,
                feeRateSatPerVbyte: 1
            )
        }
        await assertPlannerError(.invalidRecipientAddress) {
            _ = try await planner.plan(
                amountSats: 1_000,
                sources: [BitcoinUtxoSource(address: Self.mainnetAddress)],
                recipientAddress: Self.testnetAddress,
                feeRateSatPerVbyte: 1
            )
        }
        await assertPlannerError(.invalidChangeAddress) {
            _ = try await planner.plan(
                amountSats: 1_000,
                sources: [BitcoinUtxoSource(address: Self.mainnetAddress)],
                recipientAddress: Self.recipientAddress,
                changeAddress: Self.testnetAddress,
                feeRateSatPerVbyte: 1
            )
        }
        await assertPlannerError(.invalidFeeRate) {
            _ = try await planner.plan(
                amountSats: 1_000,
                sources: [BitcoinUtxoSource(address: Self.mainnetAddress)],
                recipientAddress: Self.recipientAddress,
                feeRateSatPerVbyte: 0
            )
        }
        XCTAssertTrue(client.utxoAddressCalls.isEmpty)
        XCTAssertTrue(client.feeEstimateNetworks.isEmpty)
    }

    func testPropagatesSelectionFailuresFromSpendPlanning() async {
        let client = FakeBitcoinIndexerClient(
            utxosByAddress: [Self.mainnetAddress: [Self.utxo(valueSats: 30_000)]]
        )
        let planner = BitcoinSendPlanner(client: client)

        do {
            _ = try await planner.plan(
                amountSats: 50_000,
                sources: [BitcoinUtxoSource(address: Self.mainnetAddress)],
                recipientAddress: Self.recipientAddress,
                feeRateSatPerVbyte: 1
            )
            XCTFail("Expected insufficient funds to be rejected")
        } catch {
            XCTAssertEqual(error as? BitcoinUtxoSelectionError, .insufficientFunds)
        }
    }

    private func assertPlannerError(
        _ expected: BitcoinSendPlannerError,
        file: StaticString = #filePath,
        line: UInt = #line,
        block: () async throws -> Void
    ) async {
        do {
            try await block()
            XCTFail("Expected Bitcoin send planner error \(expected)", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? BitcoinSendPlannerError, expected, file: file, line: line)
        }
    }

    private final class FakeBitcoinIndexerClient: BitcoinIndexerClientProtocol {
        private let estimates: [String: Double]
        private let utxosByAddress: [String: [BitcoinEsploraUtxo]]
        private(set) var feeEstimateNetworks: [BitcoinIndexerNetwork] = []
        private(set) var utxoAddressCalls: [String] = []

        init(
            estimates: [String: Double] = [:],
            utxosByAddress: [String: [BitcoinEsploraUtxo]] = [:]
        ) {
            self.estimates = estimates
            self.utxosByAddress = utxosByAddress
        }

        func feeEstimates(
            network: BitcoinIndexerNetwork,
            baseURL: String?
        ) async throws -> [String: Double] {
            feeEstimateNetworks.append(network)
            return estimates
        }

        func utxos(
            address: String,
            network: BitcoinIndexerNetwork,
            baseURL: String?
        ) async throws -> [BitcoinEsploraUtxo] {
            utxoAddressCalls.append(address)
            return utxosByAddress[address] ?? []
        }

        func address(
            address: String,
            network: BitcoinIndexerNetwork,
            baseURL: String?
        ) async throws -> BitcoinEsploraAddress {
            throw UnexpectedEndpointError()
        }

        func transactions(
            address: String,
            network: BitcoinIndexerNetwork,
            baseURL: String?,
            lastSeenTxid: String?,
            mempool: Bool
        ) async throws -> [BitcoinEsploraTransaction] {
            throw UnexpectedEndpointError()
        }

        func broadcastTransaction(
            txHex: String,
            network: BitcoinIndexerNetwork,
            baseURL: String?
        ) async throws -> String {
            throw UnexpectedEndpointError()
        }
    }

    private struct UnexpectedEndpointError: Error {}

    private static let mainnetAddress = "bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu"
    private static let recipientAddress = "bc1qslk39wvggqa0vl8nd6jckaz54dw3vk45c5w60m"
    private static let testnetAddress = "tb1q6rz28mcfaxtmd6v789l9rrlrusdprr9pqcpvkl"

    private static func utxo(
        valueSats: Int64,
        confirmed: Bool = true,
        txid: String = String(repeating: "11", count: 32)
    ) -> BitcoinEsploraUtxo {
        BitcoinEsploraUtxo(
            txid: txid,
            vout: 0,
            value: valueSats,
            status: BitcoinEsploraTxStatus(
                confirmed: confirmed,
                blockHash: nil,
                blockHeight: nil,
                blockTime: nil
            )
        )
    }
}
