import XCTest
@testable import fearless

final class UniversalWalletSigningContractTests: XCTestCase {
    func testValidatesAndSerializesMessageSigningRequestsAndResults() throws {
        let request = messageRequest()
        let result = approvedMessageResult()

        XCTAssertTrue(request.validationErrors().isEmpty)
        XCTAssertTrue(result.validationErrors().isEmpty)

        let requestJson = String(decoding: try JSONEncoder().encode(request), as: UTF8.self)
        let resultJson = String(decoding: try JSONEncoder().encode(result), as: UTF8.self)
        XCTAssertTrue(requestJson.contains(#""method":"sign-message""#))
        XCTAssertTrue(requestJson.contains(#""encoding":"base64""#))
        XCTAssertTrue(resultJson.contains(#""status":"approved""#))
        XCTAssertTrue(resultJson.contains(#""signatureHex":"\#(String(repeating: "ab", count: 64))""#))
    }

    func testRejectsMalformedMessageSigningRequests() {
        let request = UniversalWalletSigningRequest(
            requestId: "bad",
            accountId: "../bad",
            ecosystem: "unknown",
            chainId: "bad chain",
            origin: " https://dapp.example ",
            method: .signMessage,
            message: UniversalWalletSigningPayload(encoding: .base64, value: "*not-base64*", display: .utf8),
            transactionBase64: "AQID",
            transactionsBase64: [],
            createdAtMillis: 10,
            expiresAtMillis: 9
        )

        let errors = request.validationErrors()

        XCTAssertTrue(errors.contains(.invalidRequestId))
        XCTAssertTrue(errors.contains(.invalidAccountId))
        XCTAssertTrue(errors.contains(.invalidEcosystem))
        XCTAssertTrue(errors.contains(.invalidChainId))
        XCTAssertTrue(errors.contains(.invalidOrigin))
        XCTAssertTrue(errors.contains(.invalidBase64))
        XCTAssertTrue(errors.contains(.payloadNotAllowed))
        XCTAssertTrue(errors.contains(.invalidTimestamp))
    }

    func testValidatesTransactionAndBatchSigningRequests() {
        let transaction = UniversalWalletSigningRequest(
            requestId: "sign_1234567890abcdef",
            accountId: "solana-mainnet",
            ecosystem: "solana",
            chainId: "solana:mainnet",
            origin: "https://dapp.example",
            method: .signTransaction,
            message: nil,
            transactionBase64: "AQIDBA==",
            transactionsBase64: [],
            createdAtMillis: 1_710_000_000_000,
            expiresAtMillis: 1_710_000_060_000
        )
        let signAndSend = UniversalWalletSigningRequest(
            requestId: transaction.requestId,
            accountId: transaction.accountId,
            ecosystem: transaction.ecosystem,
            chainId: transaction.chainId,
            origin: transaction.origin,
            method: .signAndSendTransaction,
            message: nil,
            transactionBase64: transaction.transactionBase64,
            transactionsBase64: [],
            createdAtMillis: transaction.createdAtMillis,
            expiresAtMillis: transaction.expiresAtMillis
        )
        let batch = UniversalWalletSigningRequest(
            requestId: transaction.requestId,
            accountId: transaction.accountId,
            ecosystem: transaction.ecosystem,
            chainId: transaction.chainId,
            origin: transaction.origin,
            method: .signAllTransactions,
            message: nil,
            transactionBase64: nil,
            transactionsBase64: ["AQIDBA==", "BQYHCA=="],
            createdAtMillis: transaction.createdAtMillis,
            expiresAtMillis: transaction.expiresAtMillis
        )

        XCTAssertTrue(transaction.validationErrors().isEmpty)
        XCTAssertTrue(signAndSend.validationErrors().isEmpty)
        XCTAssertTrue(batch.validationErrors().isEmpty)
    }

    func testRejectsMalformedTransactionAndBatchSigningRequests() {
        let transaction = UniversalWalletSigningRequest(
            requestId: "sign_1234567890abcdef",
            accountId: "solana-mainnet",
            ecosystem: "solana",
            chainId: "solana:mainnet",
            origin: "https://dapp.example",
            method: .signTransaction,
            message: nil,
            transactionBase64: "*bad*",
            transactionsBase64: [],
            createdAtMillis: 1_710_000_000_000,
            expiresAtMillis: nil
        )
        let batch = UniversalWalletSigningRequest(
            requestId: transaction.requestId,
            accountId: transaction.accountId,
            ecosystem: transaction.ecosystem,
            chainId: transaction.chainId,
            origin: transaction.origin,
            method: .signAllTransactions,
            message: nil,
            transactionBase64: nil,
            transactionsBase64: Array(repeating: "AQIDBA==", count: 17),
            createdAtMillis: transaction.createdAtMillis,
            expiresAtMillis: nil
        )

        XCTAssertTrue(transaction.validationErrors().contains(.transactionRequired))
        XCTAssertTrue(batch.validationErrors().contains(.invalidBatch))
    }

    func testValidatesApprovedTransactionAndRejectedSigningResults() {
        let txHash = "5NfHnqDyzT9qyfxZDq2sSskAMGuFZ3VRqW4EQxghKqrKYdKq6cZNW1J34w7qE6nGx1eDQe5s2eKxB2ZtE1xU9qgN"
        let transaction = UniversalWalletSigningResult(
            requestId: "sign_1234567890abcdef",
            accountId: "solana-mainnet",
            ecosystem: "solana",
            chainId: "solana:mainnet",
            method: .signAndSendTransaction,
            status: .approved,
            publicKey: "HAgk14JpMQLgt6rVgv7cBQFJWFto5Dqxi472uT3DKpqk",
            signatureHex: nil,
            signatureBase64: nil,
            signatureBase58: nil,
            signedTransactionBase64: "AQIDBA==",
            signedTransactionsBase64: [],
            transactionHash: txHash,
            errorCode: nil,
            signedAtMillis: 1_710_000_000_100
        )
        let rejected = UniversalWalletSigningResult(
            requestId: transaction.requestId,
            accountId: transaction.accountId,
            ecosystem: transaction.ecosystem,
            chainId: transaction.chainId,
            method: .signMessage,
            status: .rejected,
            publicKey: nil,
            signatureHex: nil,
            signatureBase64: nil,
            signatureBase58: nil,
            signedTransactionBase64: nil,
            signedTransactionsBase64: [],
            transactionHash: nil,
            errorCode: "user_rejected",
            signedAtMillis: transaction.signedAtMillis
        )

        XCTAssertTrue(transaction.validationErrors().isEmpty)
        XCTAssertTrue(rejected.validationErrors().isEmpty)
    }

    func testRejectsInconsistentSigningResults() {
        let approved = UniversalWalletSigningResult(
            requestId: "sign_1234567890abcdef",
            accountId: "solana-mainnet",
            ecosystem: "solana",
            chainId: "solana:mainnet",
            method: .signMessage,
            status: .approved,
            publicKey: nil,
            signatureHex: "ABC",
            signatureBase64: nil,
            signatureBase58: nil,
            signedTransactionBase64: nil,
            signedTransactionsBase64: [],
            transactionHash: nil,
            errorCode: "not_allowed",
            signedAtMillis: 1_710_000_000_100
        )
        let failed = UniversalWalletSigningResult(
            requestId: approved.requestId,
            accountId: approved.accountId,
            ecosystem: approved.ecosystem,
            chainId: approved.chainId,
            method: approved.method,
            status: .failed,
            publicKey: "HAgk14JpMQLgt6rVgv7cBQFJWFto5Dqxi472uT3DKpqk",
            signatureHex: String(repeating: "ab", count: 64),
            signatureBase64: nil,
            signatureBase58: nil,
            signedTransactionBase64: nil,
            signedTransactionsBase64: [],
            transactionHash: nil,
            errorCode: nil,
            signedAtMillis: approved.signedAtMillis
        )

        let approvedErrors = approved.validationErrors()
        let failedErrors = failed.validationErrors()

        XCTAssertTrue(approvedErrors.contains(.publicKeyRequired))
        XCTAssertTrue(approvedErrors.contains(.invalidSignature))
        XCTAssertTrue(approvedErrors.contains(.errorNotAllowed))
        XCTAssertTrue(failedErrors.contains(.errorCodeRequired))
        XCTAssertTrue(failedErrors.contains(.signatureNotAllowed))
    }

    private func messageRequest() -> UniversalWalletSigningRequest {
        UniversalWalletSigningRequest(
            requestId: "sign_1234567890abcdef",
            accountId: "solana-mainnet",
            ecosystem: "solana",
            chainId: "solana:mainnet",
            origin: "https://dapp.example",
            method: .signMessage,
            message: UniversalWalletSigningPayload(encoding: .base64, value: "ZmVhcmxlc3M=", display: .utf8),
            transactionBase64: nil,
            transactionsBase64: [],
            createdAtMillis: 1_710_000_000_000,
            expiresAtMillis: 1_710_000_060_000
        )
    }

    private func approvedMessageResult() -> UniversalWalletSigningResult {
        UniversalWalletSigningResult(
            requestId: "sign_1234567890abcdef",
            accountId: "solana-mainnet",
            ecosystem: "solana",
            chainId: "solana:mainnet",
            method: .signMessage,
            status: .approved,
            publicKey: "HAgk14JpMQLgt6rVgv7cBQFJWFto5Dqxi472uT3DKpqk",
            signatureHex: String(repeating: "ab", count: 64),
            signatureBase64: nil,
            signatureBase58: nil,
            signedTransactionBase64: nil,
            signedTransactionsBase64: [],
            transactionHash: nil,
            errorCode: nil,
            signedAtMillis: 1_710_000_000_100
        )
    }
}
