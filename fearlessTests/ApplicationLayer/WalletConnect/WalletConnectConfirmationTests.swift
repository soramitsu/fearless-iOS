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

    // MARK: - Calls the wallet cannot fully explain

    func testUndecodedContractCall_showsAWarningTheContractItsFunctionAndTheRawData() throws {
        let contract = Data(repeating: 0xDD, count: 20)
        let data = Data([0xDE, 0xAD, 0xBE, 0xEF]) + Data(repeating: 0x01, count: 64)
        let quote = try makeQuote(to: contract, value: BigUInt("1000000000000000000"), data: data)

        let rows = try viewModel(for: .ethereumTransaction(quote), chain: Fixtures.ethereumChain()).rows

        XCTAssertEqual(
            rows.map(\.kind).prefix(7),
            [.network, .warning, .contract, .function, .data, .amount, .fee]
        )
        XCTAssertFalse(rows.contains { $0.kind == .recipient }, "A contract call has no recipient to show")
        XCTAssertTrue(rows[1].isWarning)
        XCTAssertTrue(rows[1].isMultiline)
        XCTAssertEqual(
            rows[1].value,
            R.string.localizable.walletConnectConfirmationUndecodedWarning(preferredLanguages: ["en"])
        )
        XCTAssertEqual(rows[1].title, R.string.localizable.commonWarning(preferredLanguages: ["en"]))
        XCTAssertEqual(rows[2].value, contract.toHex(includePrefix: true))
        XCTAssertEqual(rows[3].value, "0xdeadbeef")
        XCTAssertEqual(rows[4].value, data.toHex(includePrefix: true))
        XCTAssertEqual(rows[5].value, "1 ETH")
    }

    func testUndecodedContractCall_withoutValue_showsNoAmount() throws {
        let quote = try makeQuote(to: Data(repeating: 0xDD, count: 20), value: 0, data: Data([0xDE, 0xAD, 0xBE, 0xEF]))

        let rows = try viewModel(for: .ethereumTransaction(quote), chain: Fixtures.ethereumChain()).rows

        XCTAssertEqual(rows.map(\.kind).prefix(6), [.network, .warning, .contract, .function, .data, .fee])
    }

    func testLongCallData_showsTheFirst256BytesAndHowLongItIs() throws {
        let data = Data([0xDE, 0xAD, 0xBE, 0xEF]) + Data(repeating: 0xAA, count: 296)
        let quote = try makeQuote(to: Data(repeating: 0xDD, count: 20), value: 0, data: data)

        let rows = try viewModel(for: .ethereumTransaction(quote), chain: Fixtures.ethereumChain()).rows
        let dataRow = try XCTUnwrap(rows.first { $0.kind == .data })

        XCTAssertEqual(dataRow.value, Data(data.prefix(256)).toHex(includePrefix: true) + "… (300 bytes)")
    }

    func testDecodedCallWithTrailingData_warnsAndShowsTheRawData() throws {
        let contract = Data(repeating: 0xDD, count: 20)
        let recipient = Data(repeating: 0x12, count: 20)
        let data = WalletConnectRequestPreparationTests.call(
            "a9059cbb",
            WalletConnectRequestPreparationTests.word(recipient),
            WalletConnectRequestPreparationTests.word(BigUInt(5))
        ) + Data([0xCA, 0xFE])
        let quote = try makeQuote(
            to: contract,
            value: 0,
            data: data,
            tokenCall: .transfer(recipient: recipient, amount: 5),
            trailingDataLength: 2
        )

        let rows = try viewModel(for: .ethereumTransaction(quote), chain: Fixtures.ethereumChain()).rows

        XCTAssertEqual(
            rows.map(\.kind).prefix(7),
            [.network, .warning, .recipient, .amount, .contract, .data, .fee]
        )
        XCTAssertEqual(
            rows[1].value,
            R.string.localizable.walletConnectConfirmationTrailingWarning(preferredLanguages: ["en"])
        )
        XCTAssertEqual(rows[5].value, data.toHex(includePrefix: true))
    }

    func testIncreaseAllowance_atTheMaximum_isShownAsUnlimited() throws {
        let spender = Data(repeating: 0x34, count: 20)
        let quote = try makeQuote(
            to: Data(repeating: 0xDD, count: 20),
            value: 0,
            tokenCall: .increaseAllowance(spender: spender, amount: BigUInt(2).power(256) - 1)
        )

        let rows = try viewModel(for: .ethereumTransaction(quote), chain: Fixtures.ethereumChain()).rows

        XCTAssertEqual(rows.map(\.kind).prefix(5), [.network, .spender, .amount, .contract, .fee])
        XCTAssertEqual(rows[1].value, spender.toHex(includePrefix: true))
        XCTAssertEqual(rows[2].value, R.string.localizable.walletConnectConfirmationUnlimited(preferredLanguages: ["en"]))
    }

    func testTransferFrom_ofAnUnknownContract_showsTheOwnerRecipientAndTheAmountOrItem() throws {
        let owner = Data(repeating: 0x11, count: 20)
        let recipient = Data(repeating: 0x22, count: 20)
        let quote = try makeQuote(
            to: Data(repeating: 0xDD, count: 20),
            value: 0,
            tokenCall: .transferFrom(owner: owner, recipient: recipient, amountOrId: 1234)
        )

        let rows = try viewModel(for: .ethereumTransaction(quote), chain: Fixtures.ethereumChain()).rows

        XCTAssertEqual(rows.map(\.kind).prefix(6), [.network, .from, .recipient, .amount, .contract, .fee])
        XCTAssertEqual(rows[1].value, owner.toHex(includePrefix: true))
        XCTAssertEqual(rows[2].value, recipient.toHex(includePrefix: true))
        XCTAssertEqual(rows[3].title, R.string.localizable.walletConnectConfirmationAmountOrId(preferredLanguages: ["en"]))
        XCTAssertEqual(rows[3].value, "1234")
    }

    func testTransferFrom_ofAKnownToken_showsTheAmountInTheToken() throws {
        let contract = Data(repeating: 0xDD, count: 20)
        let token = Fixtures.asset(id: contract.toHex(includePrefix: true), symbol: "USDT", precision: 6)
        let quote = try makeQuote(
            to: contract,
            value: 0,
            tokenCall: .transferFrom(
                owner: Data(repeating: 0x11, count: 20),
                recipient: Data(repeating: 0x22, count: 20),
                amountOrId: 2_000_000
            )
        )

        let rows = try viewModel(for: .ethereumTransaction(quote), chain: Fixtures.ethereumChain(tokens: [token])).rows

        XCTAssertEqual(rows[3].title, R.string.localizable.walletConnectConfirmationAmount(preferredLanguages: ["en"]))
        XCTAssertEqual(rows[3].value, "2 USDT")
    }

    func testSetApprovalForAll_showsWhoMayMoveEveryItem() throws {
        let operatorAddress = Data(repeating: 0x56, count: 20)
        let approve = try makeQuote(
            to: Data(repeating: 0xDD, count: 20),
            value: 0,
            tokenCall: .setApprovalForAll(operator: operatorAddress, approved: true)
        )
        let revoke = try makeQuote(
            to: Data(repeating: 0xDD, count: 20),
            value: 0,
            tokenCall: .setApprovalForAll(operator: operatorAddress, approved: false)
        )

        let approveRows = try viewModel(for: .ethereumTransaction(approve), chain: Fixtures.ethereumChain()).rows
        let revokeRows = try viewModel(for: .ethereumTransaction(revoke), chain: Fixtures.ethereumChain()).rows

        XCTAssertEqual(approveRows.map(\.kind).prefix(5), [.network, .spender, .access, .contract, .fee])
        XCTAssertEqual(approveRows[1].title, R.string.localizable.walletConnectConfirmationOperator(preferredLanguages: ["en"]))
        XCTAssertEqual(approveRows[1].value, operatorAddress.toHex(includePrefix: true))
        XCTAssertEqual(approveRows[2].value, R.string.localizable.walletConnectConfirmationAccessAll(preferredLanguages: ["en"]))
        XCTAssertEqual(revokeRows[2].value, R.string.localizable.walletConnectConfirmationAccessNone(preferredLanguages: ["en"]))
    }

    // MARK: - Typed data

    func testUnknownTypedData_warnsAndShowsEverySignedField() throws {
        let contract = Data(repeating: 0xCC, count: 20)
        let typedData = WalletConnectTypedData(
            signingInput: Data(count: 66),
            primaryType: "Order",
            domainName: "Exchange",
            verifyingContract: contract,
            allowance: nil,
            fields: [
                WalletConnectTypedDataField(path: "domain.name", value: "Exchange"),
                WalletConnectTypedDataField(path: "message.maker", value: "0x1111111111111111111111111111111111111111"),
                WalletConnectTypedDataField(path: "message.amount", value: "500")
            ]
        )

        let rows = try viewModel(for: .ethereumTypedData(typedData), chain: Fixtures.ethereumChain()).rows

        XCTAssertEqual(
            rows.map(\.kind).prefix(8),
            [.network, .warning, .contract, .field, .field, .field, .message, .fee]
        )
        XCTAssertEqual(rows[1].value, R.string.localizable.walletConnectConfirmationTypedWarning(preferredLanguages: ["en"]))
        XCTAssertEqual(rows[2].value, contract.toHex(includePrefix: true))
        XCTAssertEqual(rows[3].title, "domain.name")
        XCTAssertEqual(rows[4].title, "message.maker")
        XCTAssertEqual(rows[4].value, "0x1111111111111111111111111111111111111111")
        XCTAssertEqual(rows[5].value, "500")
        XCTAssertTrue(rows[5].isMultiline)
    }

    func testPermit_showsHowLongTheAllowanceLasts() throws {
        let token = Data(repeating: 0x7B, count: 20)
        let spender = Data(repeating: 0x5A, count: 20)
        let typedData = WalletConnectTypedData(
            signingInput: Data(count: 66),
            primaryType: "Permit",
            domainName: "Dai Stablecoin",
            verifyingContract: token,
            allowance: WalletConnectTokenAllowance(
                token: token,
                spender: spender,
                amount: BigUInt(2).power(256) - 1,
                deadline: 1_900_000_000
            )
        )

        let rows = try viewModel(for: .ethereumTypedData(typedData), chain: Fixtures.ethereumChain()).rows

        XCTAssertEqual(rows.map(\.kind).prefix(7), [.network, .spender, .amount, .contract, .deadline, .message, .fee])
        XCTAssertEqual(rows[2].value, R.string.localizable.walletConnectConfirmationUnlimited(preferredLanguages: ["en"]))
        XCTAssertEqual(rows[4].value, WalletConnectConfirmationViewModelFactoryImpl.date(1_900_000_000, locale: english))
        XCTAssertNotEqual(rows[4].value, "1900000000")
    }

    func testDeadlineBeyondAnyDate_isShownAsTheNumber() {
        let never = BigUInt(2).power(48) - 1

        XCTAssertEqual(WalletConnectConfirmationViewModelFactoryImpl.date(never, locale: english), String(never))
    }

    func testPermitWhoseAmountCannotBeRead_warnsAndSaysSo() throws {
        let spender = Data(repeating: 0x5A, count: 20)
        let typedData = WalletConnectTypedData(
            signingInput: Data(count: 66),
            primaryType: "Permit",
            domainName: "Token",
            verifyingContract: Data(repeating: 0x7B, count: 20),
            allowance: WalletConnectTokenAllowance(token: Data(repeating: 0x7B, count: 20), spender: spender, amount: nil),
            fields: [WalletConnectTypedDataField(path: "message.value", value: "1.5")]
        )

        let rows = try viewModel(for: .ethereumTypedData(typedData), chain: Fixtures.ethereumChain()).rows

        XCTAssertEqual(
            rows.map(\.kind).prefix(7),
            [.network, .warning, .spender, .amount, .contract, .field, .message]
        )
        XCTAssertEqual(rows[2].value, spender.toHex(includePrefix: true))
        XCTAssertEqual(rows[3].value, R.string.localizable.walletConnectConfirmationUnreadable(preferredLanguages: ["en"]))
    }

    func testTypedDataForNoNetwork_warnsThatTheSignatureWorksOnOtherNetworks() throws {
        let typedData = WalletConnectTypedData(
            signingInput: Data(count: 66),
            primaryType: "Login",
            domainName: "Example",
            verifyingContract: nil,
            allowance: nil,
            fields: [WalletConnectTypedDataField(path: "message.nonce", value: "7")],
            isChainUnbound: true
        )

        let rows = try viewModel(for: .ethereumTypedData(typedData), chain: Fixtures.ethereumChain()).rows

        XCTAssertEqual(rows.map(\.kind).prefix(5), [.network, .warning, .warning, .field, .message])
        XCTAssertEqual(rows[1].value, R.string.localizable.walletConnectConfirmationUnboundWarning(preferredLanguages: ["en"]))
    }

    // MARK: - Polkadot calls

    func testPolkadotBatch_showsEveryInnerCallWithItsArguments() throws {
        let chain = Fixtures.westend()
        let first = Data(repeating: 0x42, count: 32)
        let call = RuntimeCall(
            moduleName: "Utility",
            callName: "batch_all",
            args: JSON.dictionaryValue([
                "calls": .arrayValue([
                    Self.call("Balances", "transfer_keep_alive", [
                        "dest": .arrayValue([.stringValue("Id"), .stringValue(first.toHex(includePrefix: true))]),
                        "value": .stringValue("2500000000000")
                    ]),
                    Self.call("System", "remark", ["remark": .stringValue("0x68656c6c6f")])
                ])
            ])
        )

        let rows = try viewModel(for: .polkadotTransaction(makeExtrinsic(call: call)), chain: chain).rows

        XCTAssertEqual(rows.map(\.kind).prefix(5), [.network, .warning, .call, .arguments, .fee])
        XCTAssertEqual(rows[1].value, R.string.localizable.walletConnectConfirmationCallWarning(preferredLanguages: ["en"]))
        XCTAssertEqual(rows[2].value, "Utility.batch_all")
        XCTAssertEqual(rows[3].title, R.string.localizable.walletConnectConfirmationArguments(preferredLanguages: ["en"]))
        XCTAssertEqual(rows[3].value, [
            "calls:",
            "  1. Balances.transfer_keep_alive",
            "     dest: \(try AddressFactory.address(for: first, chain: chain))",
            "     value: 2.5 WND",
            "  2. System.remark",
            "     remark: 0x68656c6c6f"
        ].joined(separator: "\n"))
        XCTAssertTrue(rows[3].isMultiline)
    }

    func testPolkadotProxy_showsTheAccountItActsForAndTheInnerCall() throws {
        let chain = Fixtures.westend()
        let real = Data(repeating: 0x24, count: 32)
        let recipient = Data(repeating: 0x42, count: 32)
        let call = RuntimeCall(
            moduleName: "Proxy",
            callName: "proxy",
            args: JSON.dictionaryValue([
                "real": .arrayValue([.stringValue("Id"), .stringValue(real.toHex(includePrefix: true))]),
                "force_proxy_type": .null,
                "call": Self.call("Balances", "transfer_allow_death", [
                    "dest": .arrayValue([.stringValue("Id"), .stringValue(recipient.toHex(includePrefix: true))]),
                    "value": .stringValue("1000000000000")
                ])
            ])
        )

        let rows = try viewModel(for: .polkadotTransaction(makeExtrinsic(call: call)), chain: chain).rows

        XCTAssertEqual(rows[2].value, "Proxy.proxy")
        XCTAssertEqual(rows[3].value, [
            "call: Balances.transfer_allow_death",
            "  dest: \(try AddressFactory.address(for: recipient, chain: chain))",
            "  value: 1 WND",
            "force_proxy_type: None",
            "real: \(try AddressFactory.address(for: real, chain: chain))"
        ].joined(separator: "\n"))
    }

    func testPolkadotOtherCall_showsItsArgumentsAsDecoded() throws {
        let chain = Fixtures.westend()
        let target = Data(repeating: 0x33, count: 32)
        let call = RuntimeCall(
            moduleName: "Staking",
            callName: "nominate",
            args: JSON.dictionaryValue([
                "targets": .arrayValue([
                    .arrayValue([.stringValue("Id"), .stringValue(target.toHex(includePrefix: true))]),
                    .arrayValue([.stringValue("Index"), .stringValue("5")])
                ])
            ])
        )

        let rows = try viewModel(for: .polkadotTransaction(makeExtrinsic(call: call)), chain: chain).rows

        XCTAssertEqual(rows.map(\.kind).prefix(5), [.network, .warning, .call, .arguments, .fee])
        XCTAssertEqual(rows[3].value, [
            "targets:",
            "  1. \(try AddressFactory.address(for: target, chain: chain))",
            "  2. Index 5"
        ].joined(separator: "\n"))
    }

    func testPolkadotCallText_showsAmountsOfOtherModulesAsDecodedAndCapsLongValues() {
        let text = WalletConnectSubstrateCallText(address: { _ in nil }, nativeAmount: { "\($0) NATIVE" })
        let remark = String(repeating: "ab", count: 600)

        let assets = text.text(forArgumentsOf: RuntimeCall(
            moduleName: "Assets",
            callName: "transfer",
            args: JSON.dictionaryValue(["id": .unsignedIntValue(1984), "amount": .stringValue("5"), "value": .stringValue("7")])
        ))
        let remarkText = text.text(forArgumentsOf: RuntimeCall(
            moduleName: "System",
            callName: "remark",
            args: JSON.dictionaryValue(["remark": .stringValue(remark)])
        ))

        // Only `Balances` amounts are in the native asset.
        XCTAssertEqual(assets, "amount: 5\nid: 1984\nvalue: 7")
        XCTAssertEqual(remarkText, "remark: \(remark.prefix(512))… (1200 characters)")
    }

    func testPolkadotCallText_whenCallsNestTooDeep_thenEndsWithAnEllipsis() {
        var nested = Self.call("System", "remark", ["remark": .stringValue("0x00")])
        for _ in 0 ..< 40 {
            nested = Self.call("Utility", "batch", ["calls": .arrayValue([nested])])
        }
        guard case let .arrayValue(outer) = nested, case let .arrayValue(inner) = outer[1] else {
            return XCTFail("Not a call")
        }
        let text = WalletConnectSubstrateCallText(address: { _ in nil }, nativeAmount: { _ in nil })
            .text(forArgumentsOf: RuntimeCall(moduleName: "Utility", callName: "batch", args: inner[1]))

        XCTAssertTrue(text.hasSuffix("\n…"), text)
        XCTAssertFalse(text.contains("System.remark"))
    }

    func testPolkadotCallText_whenTheTextIsTooLong_thenEndsWithAnEllipsis() {
        let calls = (0 ..< 2000).map { index in
            Self.call("System", "remark", ["remark": .stringValue("0x\(String(index, radix: 16))")])
        }
        let text = WalletConnectSubstrateCallText(address: { _ in nil }, nativeAmount: { _ in nil })
            .text(forArgumentsOf: RuntimeCall(
                moduleName: "Utility",
                callName: "batch",
                args: JSON.dictionaryValue(["calls": .arrayValue(calls)])
            ))

        XCTAssertLessThanOrEqual(text.count, WalletConnectSubstrateCallText.maxLength + 2)
        XCTAssertTrue(text.hasSuffix("\n…"))
        XCTAssertTrue(text.hasPrefix("calls:\n  1. System.remark\n     remark: 0x0"))
    }

    func testEveryBlindSigningStringIsTranslatedInEveryShippedLanguage() throws {
        let keys = [
            "from", "amount.or.id", "operator", "access", "access.all", "access.none", "undecoded.warning",
            "function", "data", "trailing.warning", "unbound.warning", "deadline", "typed.warning", "unreadable",
            "call.warning", "arguments"
        ].map { "wallet.connect.confirmation.\($0)" }
        let english = try XCTUnwrap(Bundle.main.path(forResource: "en", ofType: "lproj").flatMap(Bundle.init(path:)))
        let languages = Bundle.main.localizations.filter { $0 != "Base" }
        XCTAssertGreaterThanOrEqual(languages.count, 8)

        for language in languages {
            let bundle = try XCTUnwrap(
                Bundle.main.path(forResource: language, ofType: "lproj").flatMap(Bundle.init(path:)),
                language
            )
            for key in keys {
                let missing = "\u{1}missing"
                let value = bundle.localizedString(forKey: key, value: missing, table: "Localizable")
                XCTAssertNotEqual(value, missing, "\(language) has no \(key)")
                XCTAssertFalse(value.isEmpty, "\(language): \(key)")
                if language != "en", key.hasSuffix("warning") {
                    let englishValue = english.localizedString(forKey: key, value: missing, table: "Localizable")
                    XCTAssertNotEqual(value, englishValue, "\(language) still shows English for \(key)")
                }
            }
        }
    }

    // MARK: - Helpers

    private func makeQuote(
        to recipient: Data,
        value: BigUInt,
        data: Data = Data(),
        tokenCall: WalletConnectTokenCall? = nil,
        trailingDataLength: Int = 0
    ) throws -> WalletConnectEthereumTransactionQuote {
        WalletConnectEthereumTransactionQuote(
            chainId: 1,
            from: Data(repeating: 0x01, count: 20),
            to: recipient,
            value: value,
            data: data,
            nonce: 7,
            gasLimit: 21000,
            fee: .legacy(gasPrice: 20_000_000_000),
            tokenCall: tokenCall,
            trailingDataLength: trailingDataLength
        )
    }

    private func makeExtrinsic(call: RuntimeCall<JSON>) -> WalletConnectPolkadotExtrinsic {
        WalletConnectPolkadotExtrinsic(
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
            tip: 0,
            call: call,
            transfer: nil,
            fee: 15_600_000_000
        )
    }

    /// A call as the runtime decodes it: `[module, [call, args]]`.
    private static func call(_ module: String, _ name: String, _ args: [String: JSON]) -> JSON {
        .arrayValue([.stringValue(module), .arrayValue([.stringValue(name), .dictionaryValue(args)])])
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
