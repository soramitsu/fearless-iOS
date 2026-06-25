import XCTest
@testable import fearless

final class UniversalWalletIndexerContractTests: XCTestCase {
    func testValidatesAndSerializesNormalizedAssetBalances() throws {
        let balance = assetBalance()

        XCTAssertTrue(balance.validationErrors().isEmpty)

        let json = String(decoding: try JSONEncoder().encode(balance), as: UTF8.self)
        XCTAssertTrue(json.contains(#""ecosystem":"solana""#))
        XCTAssertTrue(json.contains(#""assetId":"SOL""#))
        XCTAssertTrue(json.contains(#""amount":"123456789""#))
        XCTAssertTrue(json.contains(#""tokenProgram":"spl-token""#))
    }

    func testRejectsMalformedAssetBalances() {
        let balance = UniversalWalletIndexedAssetBalance(
            accountId: "../bad",
            ecosystem: "unknown",
            chainId: "../bad",
            assetId: " SOL ",
            amount: "-1",
            decimals: 256,
            isNative: true,
            symbol: "bad\u{0000}symbol",
            name: "bad\u{0000}name",
            uiAmountString: nil,
            tokenAccountId: " token ",
            contractAddress: " contract ",
            tokenProgram: " token program ",
            syncedAtMillis: 0
        )

        let errors = balance.validationErrors()

        XCTAssertTrue(errors.contains(.invalidAccountId))
        XCTAssertTrue(errors.contains(.invalidEcosystem))
        XCTAssertTrue(errors.contains(.invalidChainId))
        XCTAssertTrue(errors.contains(.invalidAssetId))
        XCTAssertTrue(errors.contains(.invalidAmount))
        XCTAssertTrue(errors.contains(.invalidDecimals))
        XCTAssertTrue(errors.contains(.invalidSymbol))
        XCTAssertTrue(errors.contains(.invalidName))
        XCTAssertTrue(errors.contains(.invalidAddress))
        XCTAssertTrue(errors.contains(.invalidSyncedAt))
    }

    func testValidatesAndSerializesNormalizedTransactions() throws {
        let transaction = indexedTransaction()

        XCTAssertTrue(transaction.validationErrors().isEmpty)

        let json = String(decoding: try JSONEncoder().encode(transaction), as: UTF8.self)
        XCTAssertTrue(json.contains(#""status":"confirmed""#))
        XCTAssertTrue(json.contains(#""direction":"outgoing""#))
        XCTAssertTrue(json.contains(#""operationType":"transfer""#))
    }

    func testSerializesNexusOperationBuckets() throws {
        let encoder = JSONEncoder()

        let offlineCash = indexedTransaction(operationType: .offlineCash)
        let sccp = indexedTransaction(operationType: .sccp)
        let governance = indexedTransaction(operationType: .governance)

        XCTAssertTrue(
            String(decoding: try encoder.encode(offlineCash), as: UTF8.self)
                .contains(#""operationType":"offline-cash""#)
        )
        XCTAssertTrue(
            String(decoding: try encoder.encode(sccp), as: UTF8.self)
                .contains(#""operationType":"sccp""#)
        )
        XCTAssertTrue(
            String(decoding: try encoder.encode(governance), as: UTF8.self)
                .contains(#""operationType":"governance""#)
        )
    }

    func testRejectsMalformedNormalizedTransactions() {
        let transaction = UniversalWalletIndexedTransaction(
            accountId: "bad account",
            ecosystem: "bad",
            chainId: "bad chain",
            transactionId: " tx ",
            status: .failed,
            direction: .unknown,
            operationType: .unknown,
            timestampMillis: -1,
            amount: "01",
            assetId: " asset ",
            feeAmount: "1.2",
            feeAssetId: " fee ",
            counterpartyAddress: " counterparty ",
            blockNumber: "-2",
            cursor: " cursor ",
            explorerUrl: "http://example.com/tx",
            syncedAtMillis: 0
        )

        let errors = transaction.validationErrors()

        XCTAssertTrue(errors.contains(.invalidAccountId))
        XCTAssertTrue(errors.contains(.invalidEcosystem))
        XCTAssertTrue(errors.contains(.invalidChainId))
        XCTAssertTrue(errors.contains(.invalidTransactionId))
        XCTAssertTrue(errors.contains(.invalidTimestamp))
        XCTAssertTrue(errors.contains(.invalidAmount))
        XCTAssertTrue(errors.contains(.invalidAssetId))
        XCTAssertTrue(errors.contains(.invalidAddress))
        XCTAssertTrue(errors.contains(.invalidBlockNumber))
        XCTAssertTrue(errors.contains(.invalidCursor))
        XCTAssertTrue(errors.contains(.invalidUrl))
        XCTAssertTrue(errors.contains(.invalidSyncedAt))
    }

    func testValidatesTokenMetadataAndPageInfoContracts() {
        let metadata = UniversalWalletIndexedTokenMetadata(
            ecosystem: UniversalWalletEcosystem.ton.rawValue,
            chainId: "ton:mainnet",
            assetId: "EQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM9c",
            decimals: 9,
            symbol: "TON",
            name: "Toncoin",
            iconUrl: "ipfs://bafybeigdyrzt",
            metadataUrl: "https://example.com/ton.json",
            isVerified: true,
            syncedAtMillis: 1_710_000_000_000
        )
        let pageInfo = UniversalWalletIndexerPageInfo(
            nextCursor: "next-cursor",
            limit: 100,
            total: 1,
            syncedAtMillis: 1_710_000_000_000
        )

        XCTAssertTrue(metadata.validationErrors().isEmpty)
        XCTAssertTrue(pageInfo.validationErrors().isEmpty)
    }

    func testRejectsMalformedTokenMetadataAndPageInfoContracts() {
        let metadata = UniversalWalletIndexedTokenMetadata(
            ecosystem: "bad",
            chainId: "bad chain",
            assetId: " asset ",
            decimals: -1,
            symbol: "bad\u{0000}symbol",
            name: "bad\u{0000}name",
            iconUrl: "ftp://example.com/icon.png",
            metadataUrl: "http://example.com/meta.json",
            isVerified: false,
            syncedAtMillis: 0
        )
        let pageInfo = UniversalWalletIndexerPageInfo(
            nextCursor: " cursor ",
            limit: 251,
            total: -1,
            syncedAtMillis: 0
        )

        let metadataErrors = metadata.validationErrors()
        let pageErrors = pageInfo.validationErrors()

        XCTAssertTrue(metadataErrors.contains(.invalidEcosystem))
        XCTAssertTrue(metadataErrors.contains(.invalidChainId))
        XCTAssertTrue(metadataErrors.contains(.invalidAssetId))
        XCTAssertTrue(metadataErrors.contains(.invalidDecimals))
        XCTAssertTrue(metadataErrors.contains(.invalidSymbol))
        XCTAssertTrue(metadataErrors.contains(.invalidName))
        XCTAssertTrue(metadataErrors.contains(.invalidUrl))
        XCTAssertTrue(metadataErrors.contains(.invalidSyncedAt))
        XCTAssertTrue(pageErrors.contains(.invalidCursor))
        XCTAssertTrue(pageErrors.contains(.invalidLimit))
        XCTAssertTrue(pageErrors.contains(.invalidTotal))
        XCTAssertTrue(pageErrors.contains(.invalidSyncedAt))
    }

    private func assetBalance() -> UniversalWalletIndexedAssetBalance {
        UniversalWalletIndexedAssetBalance(
            accountId: "solana-mainnet",
            ecosystem: .solana,
            chainId: "solana:mainnet",
            assetId: "SOL",
            amount: "123456789",
            decimals: 9,
            isNative: true,
            symbol: "SOL",
            name: "Solana",
            uiAmountString: "0.123456789",
            tokenProgram: "spl-token",
            syncedAtMillis: 1_710_000_000_000
        )
    }

    private func indexedTransaction(
        operationType: UniversalWalletIndexedOperationType = .transfer
    ) -> UniversalWalletIndexedTransaction {
        let txid = String(repeating: "a", count: 64)
        return UniversalWalletIndexedTransaction(
            accountId: "bitcoin-mainnet",
            ecosystem: UniversalWalletEcosystem.bitcoin.rawValue,
            chainId: "bitcoin:mainnet",
            transactionId: txid,
            status: .confirmed,
            direction: .outgoing,
            operationType: operationType,
            timestampMillis: 1_710_000_000_000,
            amount: "1000",
            assetId: "BTC",
            feeAmount: "100",
            feeAssetId: "BTC",
            counterpartyAddress: "bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu",
            blockNumber: "800000",
            cursor: txid,
            explorerUrl: "https://mempool.space/tx/\(txid)",
            syncedAtMillis: 1_710_000_000_000
        )
    }
}
