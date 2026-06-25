import Foundation

final class SolanaTransactionHistorySync {
    private let client: SolanaIndexerClientProtocol

    init(client: SolanaIndexerClientProtocol) {
        self.client = client
    }

    func history(
        wallet: String,
        assetId: String = UniversalWalletRegistry.solanaMainnet.nativeAsset.id,
        isNative: Bool = true,
        network: UniversalWalletRegistry.SolanaNetwork = UniversalWalletRegistry.solanaMainnet,
        baseURL: String? = nil,
        before: String? = nil,
        limit: Int = SolanaIndexerRoutes.defaultLimit
    ) async throws -> SolanaTransactionHistoryPage {
        let resolvedBaseURL: String
        do {
            resolvedBaseURL = try SolanaIndexerRoutes.normalizeBaseURL(baseURL ?? network.indexerBaseURL.absoluteString)
        } catch {
            throw SolanaTransactionHistoryError.invalidInput
        }
        try validateInputs(
            wallet: wallet,
            assetId: assetId,
            isNative: isNative,
            network: network,
            baseURL: resolvedBaseURL,
            before: before,
            limit: limit
        )

        _ = try await client.verifyServiceInfo(baseURL: resolvedBaseURL)
        let response = try await client.transactions(
            wallet: wallet,
            baseURL: resolvedBaseURL,
            before: before,
            limit: limit
        )
        guard response.wallet == wallet else {
            throw SolanaTransactionHistoryError.walletMismatch
        }
        guard response.syncedAt > 0 else {
            throw SolanaTransactionHistoryError.invalidPage
        }

        let transactions = response.transactions.compactMap {
            normalizeTransaction(
                $0,
                wallet: wallet,
                assetId: assetId,
                isNative: isNative,
                network: network,
                syncedAtMillis: response.syncedAt
            )
        }
        let pageInfo = UniversalWalletIndexerPageInfo(
            nextCursor: response.nextBefore.flatMap { Self.isBase58Signature($0) ? $0 : nil },
            limit: response.limit,
            total: response.total,
            syncedAtMillis: response.syncedAt
        )
        guard pageInfo.validationErrors().isEmpty else {
            throw SolanaTransactionHistoryError.invalidPage
        }

        return SolanaTransactionHistoryPage(
            wallet: wallet,
            networkId: network.id,
            chainId: network.chainId,
            assetId: assetId,
            isNative: isNative,
            transactions: transactions,
            pageInfo: pageInfo
        )
    }

    private func validateInputs(
        wallet: String,
        assetId: String,
        isNative: Bool,
        network: UniversalWalletRegistry.SolanaNetwork,
        baseURL: String,
        before: String?,
        limit: Int
    ) throws {
        do {
            _ = try SolanaIndexerRoutes.transactionsURL(
                wallet: wallet,
                baseURL: baseURL,
                before: before,
                limit: limit
            )
            if isNative {
                guard assetId == network.nativeAsset.id else {
                    throw SolanaIndexerRouteError.invalidMint
                }
            } else {
                _ = try SolanaIndexerRoutes.tokenMetadataURL(mint: assetId, baseURL: baseURL)
            }
        } catch {
            throw SolanaTransactionHistoryError.invalidInput
        }
    }

    private func normalizeTransaction(
        _ transaction: SolanaWalletTransactionRecord,
        wallet _: String,
        assetId: String,
        isNative: Bool,
        network: UniversalWalletRegistry.SolanaNetwork,
        syncedAtMillis: Int64
    ) -> UniversalWalletIndexedTransaction? {
        guard Self.isBase58Signature(transaction.signature), transaction.slot >= 0 else {
            return nil
        }
        guard let amount = amountDelta(transaction, assetId: assetId, isNative: isNative), !amount.isZero else {
            return nil
        }
        guard let fee = Self.unsignedInteger(transaction.feeLamports ?? "0") else {
            return nil
        }
        let timestampMillis = transaction.timestamp.multipliedReportingOverflow(by: 1000)
        guard !timestampMillis.overflow, timestampMillis.partialValue > 0 else {
            return nil
        }
        let status: UniversalWalletIndexedTransactionStatus
        switch transaction.status {
        case "success":
            status = .confirmed
        case "failed":
            status = .failed
        default:
            return nil
        }

        let indexed = UniversalWalletIndexedTransaction(
            accountId: network.id,
            ecosystem: UniversalWalletEcosystem.solana.rawValue,
            chainId: network.chainId,
            transactionId: transaction.signature,
            status: status,
            direction: amount.isNegative ? .outgoing : .incoming,
            operationType: transaction.solswapRoute == nil ? .transfer : .swap,
            timestampMillis: timestampMillis.partialValue,
            amount: amount.absoluteDigits,
            assetId: assetId,
            feeAmount: fee,
            feeAssetId: network.nativeAsset.id,
            counterpartyAddress: nil,
            blockNumber: String(transaction.slot),
            cursor: transaction.signature,
            explorerUrl: nil,
            syncedAtMillis: syncedAtMillis
        )

        return indexed.validationErrors().isEmpty ? indexed : nil
    }

    private func amountDelta(
        _ transaction: SolanaWalletTransactionRecord,
        assetId: String,
        isNative: Bool
    ) -> SignedDecimalInteger? {
        if isNative {
            return Self.signedInteger(transaction.nativeBalanceChangeLamports)
        }

        return transaction.tokenBalanceChanges.reduce(nil) { total, change -> SignedDecimalInteger? in
            guard change.mint == assetId, let delta = Self.signedInteger(change.amountDelta) else {
                return total
            }

            return (total ?? .zero).adding(delta)
        }
    }

    private struct SignedDecimalInteger: Equatable {
        static let zero = SignedDecimalInteger(sign: 0, digits: "0")

        let sign: Int
        let digits: String

        var isZero: Bool {
            sign == 0
        }

        var isNegative: Bool {
            sign < 0
        }

        var absoluteDigits: String {
            digits
        }

        init(sign: Int, digits: String) {
            self.sign = digits == "0" ? 0 : sign
            self.digits = Self.trimLeadingZeros(digits)
        }

        func adding(_ other: SignedDecimalInteger) -> SignedDecimalInteger {
            if isZero {
                return other
            }
            if other.isZero {
                return self
            }
            if sign == other.sign {
                return SignedDecimalInteger(sign: sign, digits: Self.addDigits(digits, other.digits))
            }

            switch Self.compareDigits(digits, other.digits) {
            case 1:
                return SignedDecimalInteger(sign: sign, digits: Self.subtractDigits(digits, other.digits))
            case -1:
                return SignedDecimalInteger(sign: other.sign, digits: Self.subtractDigits(other.digits, digits))
            default:
                return .zero
            }
        }

        private static func addDigits(_ left: String, _ right: String) -> String {
            var carry = 0
            var result: [Character] = []
            let leftDigits = Array(left.reversed()).map { Int(String($0))! }
            let rightDigits = Array(right.reversed()).map { Int(String($0))! }
            let count = max(leftDigits.count, rightDigits.count)

            for index in 0 ..< count {
                let sum = (index < leftDigits.count ? leftDigits[index] : 0) +
                    (index < rightDigits.count ? rightDigits[index] : 0) +
                    carry
                result.append(Character(String(sum % 10)))
                carry = sum / 10
            }
            if carry > 0 {
                result.append(Character(String(carry)))
            }

            return String(result.reversed())
        }

        private static func subtractDigits(_ left: String, _ right: String) -> String {
            var borrow = 0
            var result: [Character] = []
            let leftDigits = Array(left.reversed()).map { Int(String($0))! }
            let rightDigits = Array(right.reversed()).map { Int(String($0))! }

            for index in 0 ..< leftDigits.count {
                var digit = leftDigits[index] - borrow - (index < rightDigits.count ? rightDigits[index] : 0)
                if digit < 0 {
                    digit += 10
                    borrow = 1
                } else {
                    borrow = 0
                }
                result.append(Character(String(digit)))
            }

            return trimLeadingZeros(String(result.reversed()))
        }

        private static func compareDigits(_ left: String, _ right: String) -> Int {
            if left.count != right.count {
                return left.count > right.count ? 1 : -1
            }
            if left == right {
                return 0
            }

            return left > right ? 1 : -1
        }

        private static func trimLeadingZeros(_ value: String) -> String {
            let trimmed = value.drop { $0 == "0" }
            return trimmed.isEmpty ? "0" : String(trimmed)
        }
    }

    private static func signedInteger(_ value: String?) -> SignedDecimalInteger? {
        guard let value, matches(value, #"^-?(0|[1-9][0-9]*)$"#) else {
            return nil
        }
        if value == "0" || value == "-0" {
            return .zero
        }
        if value.hasPrefix("-") {
            return SignedDecimalInteger(sign: -1, digits: String(value.dropFirst()))
        }

        return SignedDecimalInteger(sign: 1, digits: value)
    }

    private static func unsignedInteger(_ value: String) -> String? {
        matches(value, #"^(0|[1-9][0-9]*)$"#) ? value : nil
    }

    private static func isBase58Signature(_ value: String) -> Bool {
        matches(value, #"^[1-9A-HJ-NP-Za-km-z]{64,128}$"#)
    }

    private static func matches(_ value: String, _ pattern: String) -> Bool {
        value.range(of: pattern, options: .regularExpression) != nil
    }
}

struct SolanaTransactionHistoryPage: Equatable {
    let wallet: String
    let networkId: String
    let chainId: String
    let assetId: String
    let isNative: Bool
    let transactions: [UniversalWalletIndexedTransaction]
    let pageInfo: UniversalWalletIndexerPageInfo
}

enum SolanaTransactionHistoryError: Error, Equatable {
    case invalidInput
    case walletMismatch
    case invalidPage
}
