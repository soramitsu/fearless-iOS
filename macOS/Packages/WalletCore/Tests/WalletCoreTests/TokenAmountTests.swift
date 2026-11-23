import Foundation
import Testing
@testable import WalletCore

private let posix = Locale(identifier: "en_US_POSIX")
private let us = Locale(identifier: "en_US")
private let german = Locale(identifier: "de_DE")

@Suite struct TokenAmountTests {
    @Test func rejectsNonDigitUnits() {
        #expect(TokenAmount(units: "", decimals: 10) == nil)
        #expect(TokenAmount(units: "-1", decimals: 10) == nil)
        #expect(TokenAmount(units: "1.0", decimals: 10) == nil)
        #expect(TokenAmount(units: "١٢", decimals: 10) == nil)
        #expect(TokenAmount(units: "1", decimals: -1) == nil)
        #expect(TokenAmount(units: "1", decimals: 78) == nil)
    }

    @Test func normalizesLeadingZeros() throws {
        let amount = try #require(TokenAmount(units: "000120", decimals: 2))
        #expect(amount.units == "120")
        #expect(try #require(TokenAmount(units: "0000", decimals: 2)).units == "0")
        #expect(amount == TokenAmount(units: "120", decimals: 2))
    }

    @Test func splitsIntegerAndFraction() throws {
        let dot = try #require(TokenAmount(units: "12345000000", decimals: 10))
        #expect(dot.integerDigits == "1")
        #expect(dot.fractionDigits == "2345000000")
        #expect(dot.plainString == "1.2345")
        let small = try #require(TokenAmount(units: "5", decimals: 10))
        #expect(small.integerDigits == "0")
        #expect(small.plainString == "0.0000000005")
        let whole = try #require(TokenAmount(units: "7", decimals: 0))
        #expect(whole.plainString == "7")
        #expect(TokenAmount.zero(decimals: 18).plainString == "0")
    }

    @Test func parsesUserInputExactly() throws {
        #expect(TokenAmount(decimalString: "1.5", decimals: 10, locale: posix)?.units == "15000000000")
        #expect(TokenAmount(decimalString: ".5", decimals: 2, locale: posix)?.units == "50")
        #expect(TokenAmount(decimalString: "5.", decimals: 2, locale: posix)?.units == "500")
        #expect(TokenAmount(decimalString: " 1 234.5 ", decimals: 1, locale: us)?.units == "12345")
        #expect(TokenAmount(decimalString: "1,234.5", decimals: 1, locale: us)?.units == "12345")
        #expect(TokenAmount(decimalString: "1.234,5", decimals: 1, locale: german)?.units == "12345")
        #expect(TokenAmount(decimalString: "0,25", decimals: 2, locale: german)?.units == "25")
        #expect(TokenAmount(decimalString: "0.25", decimals: 2, locale: german)?.units == "25")
        #expect(TokenAmount(decimalString: "1.50", decimals: 1, locale: posix)?.units == "15")
        let huge = "115792089237316195423570985008687907853269984665640564039457584007913129639935"
        #expect(TokenAmount(decimalString: huge, decimals: 0, locale: posix)?.units == huge)
    }

    @Test func rejectsAmbiguousOrLossyInput() {
        #expect(TokenAmount(decimalString: "", decimals: 2, locale: posix) == nil)
        #expect(TokenAmount(decimalString: ".", decimals: 2, locale: posix) == nil)
        #expect(TokenAmount(decimalString: "-1", decimals: 2, locale: posix) == nil)
        #expect(TokenAmount(decimalString: "1e5", decimals: 2, locale: posix) == nil)
        #expect(TokenAmount(decimalString: "1.2.3", decimals: 2, locale: posix) == nil)
        #expect(TokenAmount(decimalString: "0.001", decimals: 2, locale: posix) == nil)
        #expect(TokenAmount(decimalString: "abc", decimals: 2, locale: posix) == nil)
    }

    @Test func formatsWithTruncationAndGrouping() throws {
        let amount = try #require(TokenAmount(units: "1234567891234567", decimals: 10))
        #expect(amount.formatted(maximumFractionDigits: 4, locale: us) == "123,456.7891")
        #expect(amount.formatted(maximumFractionDigits: 2, locale: german) == "123.456,78")
        #expect(amount.formatted(maximumFractionDigits: 0, locale: us) == "123,456")
        let round = try #require(TokenAmount(units: "10000000000", decimals: 10))
        #expect(round.formatted(maximumFractionDigits: 4, locale: us) == "1")
        #expect(round.formatted(maximumFractionDigits: 4, minimumFractionDigits: 2, locale: us) == "1.00")
        let dust = try #require(TokenAmount(units: "1", decimals: 10))
        #expect(dust.formatted(maximumFractionDigits: 4, locale: us) == "< 0.0001")
        #expect(dust.formatted(maximumFractionDigits: 0, locale: us) == "< 1")
        #expect(TokenAmount.zero(decimals: 10).formatted(locale: us) == "0")
    }

    @Test func addsAndSubtractsExactly() throws {
        let a = try #require(TokenAmount(units: "999999999999999999999999", decimals: 18))
        let b = try #require(TokenAmount(units: "1", decimals: 18))
        #expect(a.adding(b)?.units == "1000000000000000000000000")
        #expect(a.adding(b)?.subtracting(b) == a)
        #expect(b.subtracting(a) == nil)
        #expect(b.subtractingClamped(a).isZero)
        #expect(a.subtracting(a)?.units == "0")
        let other = try #require(TokenAmount(units: "1", decimals: 6))
        #expect(a.adding(other) == nil)
    }

    @Test func comparesAcrossLengthsAndScales() throws {
        let one = try #require(TokenAmount(units: "10", decimals: 1))
        let nine = try #require(TokenAmount(units: "9", decimals: 1))
        #expect(nine < one)
        #expect(!(one < nine))
        let oneScaled = try #require(TokenAmount(units: "100", decimals: 2))
        #expect(!(one < oneScaled) && !(oneScaled < one))
        #expect(TokenAmount.zero(decimals: 3) < nine)
    }

    @Test func decimalValueIsApproximate() throws {
        let amount = try #require(TokenAmount(units: "15000000000", decimals: 10))
        #expect(amount.decimalValue == Decimal(string: "1.5"))
        #expect(amount.fiatValue(unitPrice: 4) == Decimal(6))
    }

    @Test func codableRoundTrip() throws {
        let amount = try #require(TokenAmount(units: "42", decimals: 3))
        let data = try JSONEncoder().encode(amount)
        #expect(try JSONDecoder().decode(TokenAmount.self, from: data) == amount)
    }
}

@Suite struct PasswordPolicyTests {
    @Test func scoresPasswords() {
        #expect(PasswordPolicy.evaluate("short1!") == .tooShort)
        #expect(PasswordPolicy.evaluate("password") == .weak)
        #expect(PasswordPolicy.evaluate("aaaaaaaaaaaa") == .weak)
        #expect(PasswordPolicy.evaluate("abcdefgh") == .weak)
        #expect(PasswordPolicy.evaluate("abcdefg1") == .weak)
        #expect(PasswordPolicy.evaluate("abcdefG1") == .fair)
        #expect(PasswordPolicy.evaluate("Abcdefg1!xyz") == .strong)
        #expect(PasswordPolicy.isAcceptable("abcdefG1"))
        #expect(!PasswordPolicy.isAcceptable("12345678"))
    }
}

@Suite struct ModelTests {
    @Test func explorerLinksEncodeValues() {
        let explorer = Explorer(
            name: "Subscan",
            transactionURLTemplate: "https://polkadot.subscan.io/extrinsic/{hash}",
            accountURLTemplate: "https://polkadot.subscan.io/account/{address}"
        )
        #expect(explorer.transactionURL(hash: "0xabc")?.absoluteString == "https://polkadot.subscan.io/extrinsic/0xabc")
        #expect(explorer.accountURL(address: "1abc")?.absoluteString == "https://polkadot.subscan.io/account/1abc")
        #expect(explorer.accountURL(address: "a/b?c")?.absoluteString == "https://polkadot.subscan.io/account/a%2Fb%3Fc")
        #expect(Explorer(name: "x", transactionURLTemplate: nil, accountURLTemplate: nil).transactionURL(hash: "1") == nil)
    }

    @Test func walletHelpers() {
        let substrate = WalletAccount(ecosystem: .substrate, cryptoType: .sr25519, publicKey: Data(repeating: 1, count: 32), derivationPath: nil)
        let wallet = Wallet(name: "Main", origin: .created, accounts: [substrate], isBackedUp: false)
        #expect(wallet.account(for: .substrate) == substrate)
        #expect(wallet.account(for: .evm) == nil)
        #expect(wallet.hasRecoveryPhrase)
        #expect(!wallet.isWatchOnly)
        #expect(wallet.ecosystems == [.substrate])
        #expect(AssetID.native("abc").isNative)
        #expect(FiatCurrency.named("EUR") == .eur)
    }

    @Test func preparationCanSubmitOnlyWithFeeAndNoIssues() throws {
        let asset = AssetID.native("dot")
        let amount = try #require(TokenAmount(units: "1", decimals: 10))
        let request = TransferRequest(walletID: WalletID(), assetID: asset, recipient: "x", amount: amount)
        let fee = FeeEstimate(assetID: asset, amount: amount)
        #expect(TransferPreparation(request: request, fee: fee, issues: [], maxSendable: nil).canSubmit)
        #expect(!TransferPreparation(request: request, fee: nil, issues: [], maxSendable: nil).canSubmit)
        #expect(!TransferPreparation(request: request, fee: fee, issues: [.amountIsZero], maxSendable: nil).canSubmit)
    }
}
