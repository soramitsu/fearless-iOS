import BigInt
import FearlessWalletConnect
import Foundation
import SoraKeystore
import SSFModels
import SSFUtils
import XCTest
@testable import fearless

/// The WalletConnect confirmation shows what is signed, network first, then who receives
/// what and the most the network can charge, for the account the session approved.
final class WalletConnectConfirmationTests: XCTestCase {
    private typealias Row = WalletConnectConfirmationViewModel.Row
    private typealias Fixtures = WalletConnectTestFixtures

    private let english = Locale(identifier: "en")

    func testEthereumTransaction_showsNetworkFirstThenRecipientAmountAndTheQuotedFee() throws {
        let recipient = Data(repeating: 0xAB, count: 20)
        let quote = try makeQuote(to: recipient, value: BigUInt("1500000000000000000"))

        let rows = try viewModel(for: .ethereumTransaction(quote), chain: Fixtures.ethereumChain()).rows

        XCTAssertEqual(
            rows.map(\.kind),
            [.network, .recipient, .amount, .fee, .wallet, .account, .app, .website, .verification]
        )
        XCTAssertEqual(rows[0].value, "Ethereum")
        XCTAssertEqual(rows[1].value, recipient.toHex(includePrefix: true))
        XCTAssertEqual(rows[2].value, "1.5 ETH")
        // gas limit 21000 × 20 gwei, exactly the most the signed transaction can cost
        XCTAssertEqual(rows[3].value, "0.00042 ETH")
        XCTAssertEqual(rows[6].value, "Example dApp")
        XCTAssertEqual(rows[7].value, "app.example.org")
    }

    func testTokenTransfer_showsTheTokenRecipientAndAmountAndTheContract() throws {
        let contract = Data(repeating: 0xDD, count: 20)
        let tokenRecipient = Data(repeating: 0x12, count: 20)
        let token = Fixtures.asset(id: contract.toHex(includePrefix: true), symbol: "USDT", precision: 6)
        let quote = try makeQuote(to: contract, value: 0, tokenCall: .transfer(recipient: tokenRecipient, amount: 100_500_000))

        let rows = try viewModel(for: .ethereumTransaction(quote), chain: Fixtures.ethereumChain(tokens: [token])).rows

        XCTAssertEqual(rows.map(\.kind).prefix(5), [.network, .recipient, .amount, .contract, .fee])
        XCTAssertEqual(rows[1].value, tokenRecipient.toHex(includePrefix: true))
        XCTAssertEqual(rows[2].value, "100.5 USDT")
        XCTAssertEqual(rows[3].value, contract.toHex(includePrefix: true))
    }

    func testTokenApproval_showsTheSpenderAndAnUnlimitedAmount() throws {
        let contract = Data(repeating: 0xDD, count: 20)
        let spender = Data(repeating: 0x34, count: 20)
        let quote = try makeQuote(
            to: contract,
            value: 0,
            tokenCall: .approve(spender: spender, amount: BigUInt(2).power(256) - 1)
        )

        let rows = try viewModel(for: .ethereumTransaction(quote), chain: Fixtures.ethereumChain()).rows

        XCTAssertEqual(rows.map(\.kind).prefix(5), [.network, .spender, .amount, .contract, .fee])
        XCTAssertEqual(rows[1].value, spender.toHex(includePrefix: true))
        XCTAssertEqual(rows[2].value, R.string.localizable.walletConnectConfirmationUnlimited(preferredLanguages: ["en"]))
    }

    func testMessage_showsTheMessageAndThatNoNetworkFeeIsCharged() throws {
        let message = WalletConnectMessage(bytes: Data("Sign in to Example".utf8))

        let rows = try viewModel(for: .ethereumMessage(message), chain: Fixtures.ethereumChain()).rows

        XCTAssertEqual(rows.map(\.kind), [.network, .message, .fee, .wallet, .account, .app, .website, .verification])
        XCTAssertEqual(rows[1].value, "Sign in to Example")
        XCTAssertEqual(rows[2].value, R.string.localizable.walletConnectConfirmationNoFee(preferredLanguages: ["en"]))
        XCTAssertTrue(rows[1].isMultiline)
    }

    func testBinaryMessage_isShownAsHex() {
        let message = WalletConnectMessage(bytes: Data([0x00, 0x01, 0xFF]))

        XCTAssertNil(message.text)
        XCTAssertEqual(message.displayText, "0x0001ff")
    }

    func testPermit_showsTheSpenderAmountAndToken() throws {
        let token = Data(repeating: 0x7B, count: 20)
        let spender = Data(repeating: 0x5A, count: 20)
        let typedData = WalletConnectTypedData(
            signingInput: Data(count: 66),
            primaryType: "Permit",
            domainName: "Token",
            verifyingContract: token,
            allowance: WalletConnectTokenAllowance(token: token, spender: spender, amount: 1_000_000)
        )

        let rows = try viewModel(for: .ethereumTypedData(typedData), chain: Fixtures.ethereumChain()).rows

        XCTAssertEqual(rows.map(\.kind).prefix(6), [.network, .spender, .amount, .contract, .message, .fee])
        XCTAssertEqual(rows[1].value, spender.toHex(includePrefix: true))
        XCTAssertEqual(rows[2].value, "1000000")
        XCTAssertEqual(rows[4].value, "Token · Permit")
    }

    func testPolkadotTransfer_showsRecipientAmountCallFeeAndTip() throws {
        let recipient = Data(repeating: 0x42, count: 32)
        let extrinsic = WalletConnectPolkadotExtrinsic(
            payload: TransactionPayload(
                address: "",
                blockHash: "0x00",
                blockNumber: "0x00",
                era: "0x00",
                genesisHash: "0x00",
                method: "0x00",
                nonce: "0x00",
                signedExtensions: [],
                specVersion: "0x00",
                tip: "0x00",
                transactionVersion: "0x00",
                version: 4
            ),
            specVersion: 1,
            transactionVersion: 1,
            nonce: 0,
            era: .immortal,
            tip: 1_000_000_000,
            call: RuntimeCall(moduleName: "Balances", callName: "transfer_keep_alive", args: JSON.dictionaryValue([:])),
            transfer: WalletConnectSubstrateTransfer(recipient: recipient, amount: 2_500_000_000_000),
            fee: 15_600_000_000
        )

        let chain = Fixtures.westend()
        let rows = try viewModel(for: .polkadotTransaction(extrinsic), chain: chain).rows

        XCTAssertEqual(rows.map(\.kind).prefix(6), [.network, .recipient, .amount, .call, .fee, .tip])
        XCTAssertEqual(rows[1].value, try AddressFactory.address(for: recipient, chain: chain))
        XCTAssertEqual(rows[2].value, "2.5 WND")
        XCTAssertEqual(rows[3].value, "Balances.transfer_keep_alive")
        XCTAssertEqual(rows[4].value, "0.0156 WND")
        XCTAssertEqual(rows[5].value, "0.001 WND")
    }

    func testRowTitles_areTranslatedInEveryShippedLocale() throws {
        let english = try viewModel(for: .ethereumTransaction(makeQuote(to: Data(count: 20), value: 1)), chain: Fixtures.ethereumChain())
        let shipped = Bundle.main.localizations.filter { $0 != "en" && $0 != "Base" }

        for identifier in shipped {
            let localized = try viewModel(
                for: .ethereumTransaction(makeQuote(to: Data(count: 20), value: 1)),
                chain: Fixtures.ethereumChain(),
                locale: Locale(identifier: identifier)
            )
            XCTAssertNotEqual(localized.rows[1].title, english.rows[1].title, identifier)
            XCTAssertEqual(localized.rows.map(\.kind), english.rows.map(\.kind), identifier)
        }
    }

    func testVerification_isTheLastRow() throws {
        let rows = try viewModel(
            for: .ethereumMessage(WalletConnectMessage(bytes: Data("Hi".utf8))),
            chain: WalletConnectTestFixtures.ethereumChain(),
            verification: .mismatch(origin: "https://other.example")
        ).rows

        XCTAssertEqual(rows.last?.kind, .verification)
        XCTAssertEqual(rows.last?.value, "Domain mismatch")
        // The website row shows where the request came from, not the site the app claims.
        XCTAssertEqual(rows.first { $0.kind == .website }?.value, "other.example")
    }

    // MARK: - Helpers

    private func makeQuote(
        to recipient: Data,
        value: BigUInt,
        tokenCall: WalletConnectTokenCall? = nil
    ) throws -> WalletConnectEthereumTransactionQuote {
        WalletConnectEthereumTransactionQuote(
            chainId: 1,
            from: Data(repeating: 0x01, count: 20),
            to: recipient,
            value: value,
            data: Data(),
            nonce: 7,
            gasLimit: 21000,
            fee: .legacy(gasPrice: 20_000_000_000),
            tokenCall: tokenCall
        )
    }

    private func viewModel(
        for content: WalletConnectSigningRequest.Content,
        chain: ChainModel,
        locale: Locale? = nil,
        verification: WalletConnectVerification = .verified
    ) throws -> WalletConnectConfirmationViewModel {
        let keystore = InMemoryKeychain()
        let wallet: fearless.MetaAccountModel
        let blockchain: Blockchain
        let address: String
        if chain.isEthereumBased {
            let ethereum = try Fixtures.ethereumWallet(seed: 0x01, keystore: keystore)
            wallet = ethereum.wallet
            blockchain = try Fixtures.ethereumBlockchain(chain.chainId)
            address = ethereum.addressHex
        } else {
            let substrate = try Fixtures.substrateWallet(seed: 0x01, keystore: keystore)
            wallet = substrate.wallet
            blockchain = try Fixtures.westendBlockchain()
            address = try substrate.accountId.toAddress(using: .substrate(42))
        }

        let session = try Fixtures.session(approving: [(blockchain, address)])
        let request = try Fixtures.request(method: .ethereumPersonalSign, params: "[]", chain: blockchain)
        let signingRequest = WalletConnectSigningRequest(
            request: request,
            method: .ethereumSendTransaction,
            chain: chain,
            wallet: wallet,
            account: try XCTUnwrap(wallet.fetch(for: chain.accountRequest())),
            content: content,
            preview: "",
            rawDetails: .null
        )

        let factory = WalletConnectConfirmationViewModelFactoryImpl(
            inputData: WalletConnectConfirmationInputData(
                signingRequest: signingRequest,
                session: session,
                verification: verification
            )
        )
        return factory.buildViewModel(locale: locale ?? english)
    }
}
