import BigInt
import FearlessWalletConnect
import CryptoSwift
import Foundation
import IrohaCrypto
import SoraKeystore
import SSFCrypto
import SSFModels
import SSFRuntimeCodingService
import SSFUtils
import Web3
import XCTest
@testable import fearless

/// Every WalletConnect request is decoded and checked before its confirmation opens: it
/// must name an account the session approved for the request's chain, match the network
/// (EVM chain id, EIP-712 domain, Substrate genesis hash and runtime), and be signed
/// exactly as quoted, with Substrate messages inside the `<Bytes>` envelope.
final class WalletConnectRequestPreparationTests: XCTestCase {
    private typealias Fixtures = WalletConnectTestFixtures

    // MARK: - Account binding

    func testBinding_whenAddressIsApprovedForTheChain_thenUsesTheWalletThatOwnsIt() throws {
        let keystore = InMemoryKeychain()
        let other = try Fixtures.ethereumWallet(seed: 0x21, keystore: keystore)
        let approved = try Fixtures.ethereumWallet(seed: 0x22, keystore: keystore)
        let blockchain = try Fixtures.ethereumBlockchain()
        let session = try Fixtures.session(approving: [(blockchain, approved.addressHex)])

        let binding = try WalletConnectAccountBinding.resolve(
            address: approved.addressHex.uppercased().replacingOccurrences(of: "0X", with: "0x"),
            blockchain: blockchain,
            session: session,
            wallets: [other.wallet, approved.wallet],
            chain: Fixtures.ethereumChain()
        )

        XCTAssertEqual(binding.wallet.metaId, approved.wallet.metaId)
        XCTAssertEqual(binding.account.accountId, approved.address)
    }

    func testBinding_whenAnotherWalletHoldsTheAddressButTheSessionDidNotApproveIt_thenDeclines() throws {
        let keystore = InMemoryKeychain()
        let notApproved = try Fixtures.ethereumWallet(seed: 0x21, keystore: keystore)
        let approved = try Fixtures.ethereumWallet(seed: 0x22, keystore: keystore)
        let blockchain = try Fixtures.ethereumBlockchain()
        let session = try Fixtures.session(approving: [(blockchain, approved.addressHex)])

        XCTAssertThrowsError(
            try WalletConnectAccountBinding.resolve(
                address: notApproved.addressHex,
                blockchain: blockchain,
                session: session,
                wallets: [notApproved.wallet, approved.wallet],
                chain: Fixtures.ethereumChain()
            )
        ) { error in
            XCTAssertEqual(error as? WalletConnectRequestError, .accountNotApproved)
        }
    }

    func testBinding_whenAccountIsApprovedOnlyOnAnotherChain_thenDeclines() throws {
        let keystore = InMemoryKeychain()
        let wallet = try Fixtures.ethereumWallet(seed: 0x23, keystore: keystore)
        let session = try Fixtures.session(approving: [(Fixtures.ethereumBlockchain("56"), wallet.addressHex)])

        XCTAssertThrowsError(
            try WalletConnectAccountBinding.resolve(
                address: wallet.addressHex,
                blockchain: Fixtures.ethereumBlockchain("1"),
                session: session,
                wallets: [wallet.wallet],
                chain: Fixtures.ethereumChain()
            )
        ) { error in
            XCTAssertEqual(error as? WalletConnectRequestError, .accountNotApproved)
        }
    }

    func testBinding_whenSubstrateAddressesUseDifferentPrefixes_thenMatchesTheSameAccount() throws {
        let keystore = InMemoryKeychain()
        let wallet = try Fixtures.substrateWallet(seed: 0x31, keystore: keystore)
        let blockchain = try Fixtures.westendBlockchain()
        let genericAddress = try wallet.accountId.toAddress(using: .substrate(42))
        let polkadotAddress = try wallet.accountId.toAddress(using: .substrate(0))
        let session = try Fixtures.session(approving: [(blockchain, genericAddress)])

        let binding = try WalletConnectAccountBinding.resolve(
            address: polkadotAddress,
            blockchain: blockchain,
            session: session,
            wallets: [wallet.wallet],
            chain: Fixtures.westend()
        )

        XCTAssertEqual(binding.account.accountId, wallet.accountId)
    }

    func testPrepare_whenRequestTopicIsNotTheSessions_thenDeclines() async throws {
        let keystore = InMemoryKeychain()
        let wallet = try Fixtures.ethereumWallet(seed: 0x24, keystore: keystore)
        let blockchain = try Fixtures.ethereumBlockchain()
        let session = try Fixtures.session(topic: "approved", approving: [(blockchain, wallet.addressHex)])
        let request = try Fixtures.request(
            topic: "other",
            method: .ethereumPersonalSign,
            params: "[\"0x48656c6c6f\", \"\(wallet.addressHex)\"]",
            chain: blockchain
        )

        await assertDeclines(
            try await makePreparer().prepare(request: request, session: session, wallets: [wallet.wallet], chains: [Fixtures.ethereumChain()]),
            with: .accountNotApproved
        )
    }

    // MARK: - EVM transactions

    func testEthereumTransaction_quotesEveryFieldBeforeConfirmation() async throws {
        let keystore = InMemoryKeychain()
        let wallet = try Fixtures.ethereumWallet(seed: 0x41, keystore: keystore)
        let quoting = WalletConnectQuotingStub()
        let recipient = "0x" + String(repeating: "ab", count: 20)

        let signingRequest = try await prepareTransaction(
            wallet: wallet,
            fields: "\"to\": \"\(recipient)\", \"value\": \"0xde0b6b3a7640000\", \"data\": \"0x\"",
            quoting: quoting
        )

        guard case let .ethereumTransaction(quote) = signingRequest.content else {
            return XCTFail("Expected a transaction")
        }
        XCTAssertEqual(quote.chainId, 1)
        XCTAssertEqual(quote.from, wallet.address)
        XCTAssertEqual(quote.to, try Data(hexStringSSF: recipient))
        XCTAssertEqual(quote.value, BigUInt("1000000000000000000"))
        XCTAssertEqual(quote.nonce, 7)
        XCTAssertEqual(quote.gasLimit, 21000)
        XCTAssertEqual(quote.fee, .legacy(gasPrice: 20_000_000_000))
        XCTAssertEqual(quote.maxFee, BigUInt(21000) * BigUInt(20_000_000_000))
        XCTAssertEqual(Set(quoting.calls), ["nonce", "estimateGas", "gasPrice", "eip1559"])
    }

    func testEthereumTransaction_whenDAppSuggestsGasPrice_thenTheWalletsQuoteIsShownAndSigned() async throws {
        let keystore = InMemoryKeychain()
        let wallet = try Fixtures.ethereumWallet(seed: 0x42, keystore: keystore)
        let quoting = WalletConnectQuotingStub()
        quoting.eip1559 = true

        let signingRequest = try await prepareTransaction(
            wallet: wallet,
            fields: "\"to\": \"0x\(String(repeating: "cd", count: 20))\", \"gas\": \"0x7530\", \"gasPrice\": \"0x1\", \"nonce\": \"0x2\"",
            quoting: quoting
        )

        guard case let .ethereumTransaction(quote) = signingRequest.content else {
            return XCTFail("Expected a transaction")
        }
        XCTAssertEqual(quote.gasLimit, 30000)
        XCTAssertEqual(quote.nonce, 2)
        XCTAssertEqual(quote.fee, .eip1559(maxFeePerGas: 20_000_000_000, maxPriorityFeePerGas: 20_000_000_000))
        XCTAssertFalse(quoting.calls.contains("nonce"))
        XCTAssertFalse(quoting.calls.contains("estimateGas"))
    }

    func testEthereumTransaction_whenChainIdIsDecimal_thenSignsTheQuoteForThatChain() async throws {
        let keystore = InMemoryKeychain()
        let wallet = try Fixtures.ethereumWallet(seed: 0x43, keystore: keystore)
        let chain = Fixtures.ethereumChain(chainId: "56", name: "BNB Smart Chain")
        let blockchain = try Fixtures.ethereumBlockchain("56")
        let session = try Fixtures.session(approving: [(blockchain, wallet.addressHex)])
        let request = try Fixtures.request(
            method: .ethereumSignTransaction,
            params: "[{\"from\": \"\(wallet.addressHex)\", \"to\": \"0x\(String(repeating: "ef", count: 20))\", \"value\": \"0x10\", \"chainId\": \"0x38\"}]",
            chain: blockchain
        )
        let signingRequest = try await makePreparer(quoting: WalletConnectQuotingStub())
            .prepare(request: request, session: session, wallets: [wallet.wallet], chains: [chain])

        guard case let .ethereumTransaction(quote) = signingRequest.content else {
            return XCTFail("Expected a transaction")
        }
        XCTAssertEqual(quote.chainId, 56)

        let service = EthereumTransferService(
            ws: Web3(rpcURL: "https://127.0.0.1:9").eth,
            privateKey: wallet.privateKey,
            senderAddress: wallet.addressHex
        )
        let signed = try service.sign(quote: quote)

        let expected = try EthereumTransaction(
            nonce: 7,
            gasPrice: EthereumQuantity(quantity: 20_000_000_000),
            gasLimit: 21000,
            from: wallet.privateKey.address,
            to: EthereumAddress(rawAddress: Array(repeating: 0xEF, count: 20)),
            value: 16,
            transactionType: .legacy
        ).sign(with: wallet.privateKey, chainId: 56).rawTransaction()
        let parsedAsHex = try EthereumTransaction(
            nonce: 7,
            gasPrice: EthereumQuantity(quantity: 20_000_000_000),
            gasLimit: 21000,
            from: wallet.privateKey.address,
            to: EthereumAddress(rawAddress: Array(repeating: 0xEF, count: 20)),
            value: 16,
            transactionType: .legacy
        ).sign(with: wallet.privateKey, chainId: 0x56).rawTransaction()

        XCTAssertEqual(signed, expected)
        XCTAssertNotEqual(signed, parsedAsHex)
    }

    func testEthereumChainId_parsesDecimalAndHex() {
        XCTAssertEqual(WalletConnectEthereumChainId.parse("1"), 1)
        XCTAssertEqual(WalletConnectEthereumChainId.parse("56"), 56)
        XCTAssertEqual(WalletConnectEthereumChainId.parse("137"), 137)
        XCTAssertEqual(WalletConnectEthereumChainId.parse("0x38"), 56)
        XCTAssertNil(WalletConnectEthereumChainId.parse("0xzz"))
        XCTAssertNil(WalletConnectEthereumChainId.parse("1e3"))
        XCTAssertNil(WalletConnectEthereumChainId.parse(""))
    }

    func testEthereumTransaction_whenTransactionChainIdIsAnotherNetwork_thenDeclines() async throws {
        let keystore = InMemoryKeychain()
        let wallet = try Fixtures.ethereumWallet(seed: 0x44, keystore: keystore)

        await assertDeclines(
            try await prepareTransaction(
                wallet: wallet,
                fields: "\"to\": \"0x\(String(repeating: "ab", count: 20))\", \"chainId\": \"0x38\"",
                quoting: WalletConnectQuotingStub()
            ),
            with: .networkMismatch
        )
    }

    func testEthereumTransaction_whenFromIsNotTheApprovedAccount_thenDeclines() async throws {
        let keystore = InMemoryKeychain()
        let wallet = try Fixtures.ethereumWallet(seed: 0x45, keystore: keystore)
        let intruder = try Fixtures.ethereumWallet(seed: 0x46, keystore: keystore)
        let blockchain = try Fixtures.ethereumBlockchain()
        let session = try Fixtures.session(approving: [(blockchain, wallet.addressHex)])
        let request = try Fixtures.request(
            method: .ethereumSendTransaction,
            params: "[{\"from\": \"\(intruder.addressHex)\", \"to\": \"\(wallet.addressHex)\"}]",
            chain: blockchain
        )

        await assertDeclines(
            try await makePreparer(quoting: WalletConnectQuotingStub())
                .prepare(request: request, session: session, wallets: [wallet.wallet, intruder.wallet], chains: [Fixtures.ethereumChain()]),
            with: .accountNotApproved
        )
    }

    func testEthereumTransaction_whenThereIsNoRecipient_thenDeclines() async throws {
        let keystore = InMemoryKeychain()
        let wallet = try Fixtures.ethereumWallet(seed: 0x47, keystore: keystore)

        await assertDeclines(
            try await prepareTransaction(wallet: wallet, fields: "\"data\": \"0x6080\"", quoting: WalletConnectQuotingStub()),
            with: .unsupported
        )
    }

    func testEthereumTransaction_whenValueIsAmbiguousDecimal_thenDeclines() async throws {
        let keystore = InMemoryKeychain()
        let wallet = try Fixtures.ethereumWallet(seed: 0x48, keystore: keystore)

        await assertDeclines(
            try await prepareTransaction(
                wallet: wallet,
                fields: "\"to\": \"0x\(String(repeating: "ab", count: 20))\", \"value\": \"1000\"",
                quoting: WalletConnectQuotingStub()
            ),
            with: .unsupported
        )
    }

    func testEthereumTransaction_whenFeeCannotBeQuoted_thenDeclinesBeforeConfirmation() async throws {
        let keystore = InMemoryKeychain()
        let wallet = try Fixtures.ethereumWallet(seed: 0x49, keystore: keystore)
        let quoting = WalletConnectQuotingStub()
        quoting.failure = ChainRegistryError.connectionUnavailable

        await assertDeclines(
            try await prepareTransaction(
                wallet: wallet,
                fields: "\"to\": \"0x\(String(repeating: "ab", count: 20))\"",
                quoting: quoting
            ),
            with: .feeUnavailable
        )
    }

    func testEthereumTransaction_decodesTokenTransfers() async throws {
        let keystore = InMemoryKeychain()
        let wallet = try Fixtures.ethereumWallet(seed: 0x4A, keystore: keystore)
        let recipient = String(repeating: "12", count: 20)
        let data = "0xa9059cbb" + String(repeating: "0", count: 24) + recipient +
            String(repeating: "0", count: 56) + "05f5e100"

        let signingRequest = try await prepareTransaction(
            wallet: wallet,
            fields: "\"to\": \"0x\(String(repeating: "dd", count: 20))\", \"data\": \"\(data)\"",
            quoting: WalletConnectQuotingStub()
        )

        guard case let .ethereumTransaction(quote) = signingRequest.content else {
            return XCTFail("Expected a transaction")
        }
        XCTAssertEqual(quote.tokenCall, .transfer(recipient: try Data(hexStringSSF: recipient), amount: 100_000_000))
        XCTAssertEqual(quote.trailingDataLength, 0)
        XCTAssertFalse(quote.isUndecodedCall)
    }

    func testEthereumTransaction_whenTheDataIsAnUnknownCall_thenItIsMarkedUndecoded() async throws {
        let wallet = try Fixtures.ethereumWallet(seed: 0x4B, keystore: InMemoryKeychain())
        let data = "0xdeadbeef" + String(repeating: "00", count: 64)

        let signingRequest = try await prepareTransaction(
            wallet: wallet,
            fields: "\"to\": \"0x\(String(repeating: "dd", count: 20))\", \"data\": \"\(data)\"",
            quoting: WalletConnectQuotingStub()
        )

        guard case let .ethereumTransaction(quote) = signingRequest.content else {
            return XCTFail("Expected a transaction")
        }
        XCTAssertNil(quote.tokenCall)
        XCTAssertTrue(quote.isUndecodedCall)
    }

    func testTokenCall_decodesTransferFromIncreaseAllowanceAndSetApprovalForAll() throws {
        let owner = Data(repeating: 0x11, count: 20)
        let recipient = Data(repeating: 0x22, count: 20)
        let maximum = BigUInt(2).power(256) - 1

        let transferFrom = try XCTUnwrap(WalletConnectTokenCall.decode(
            Self.call("23b872dd", Self.word(owner), Self.word(recipient), Self.word(BigUInt(7)))
        ))
        XCTAssertEqual(transferFrom.call, .transferFrom(owner: owner, recipient: recipient, amountOrId: 7))
        XCTAssertEqual(transferFrom.trailingBytes, 0)

        let increase = try XCTUnwrap(WalletConnectTokenCall.decode(
            Self.call("39509351", Self.word(recipient), Self.word(maximum))
        ))
        XCTAssertEqual(increase.call, .increaseAllowance(spender: recipient, amount: maximum))

        let approveAll = try XCTUnwrap(WalletConnectTokenCall.decode(
            Self.call("a22cb465", Self.word(recipient), Self.word(BigUInt(1)))
        ))
        XCTAssertEqual(approveAll.call, .setApprovalForAll(operator: recipient, approved: true))

        let revokeAll = try XCTUnwrap(WalletConnectTokenCall.decode(
            Self.call("a22cb465", Self.word(recipient), Self.word(BigUInt(0)))
        ))
        XCTAssertEqual(revokeAll.call, .setApprovalForAll(operator: recipient, approved: false))

        let approve = try XCTUnwrap(WalletConnectTokenCall.decode(
            Self.call("095ea7b3", Self.word(recipient), Self.word(BigUInt(5)))
        ))
        XCTAssertEqual(approve.call, .approve(spender: recipient, amount: 5))
    }

    func testTokenCall_countsBytesAfterTheArguments() throws {
        let recipient = Data(repeating: 0x22, count: 20)
        let decoded = try XCTUnwrap(WalletConnectTokenCall.decode(
            Self.call("a9059cbb", Self.word(recipient), Self.word(BigUInt(5))) + Data([0xCA, 0xFE, 0xBA, 0xBE])
        ))

        XCTAssertEqual(decoded.call, .transfer(recipient: recipient, amount: 5))
        XCTAssertEqual(decoded.trailingBytes, 4)
    }

    func testTokenCall_whenAnArgumentCouldBeReadTwoWays_thenItIsNotDecoded() {
        let recipient = Data(repeating: 0x22, count: 20)
        var dirtyAddress = Self.word(recipient)
        dirtyAddress[0] = 0x01

        // An address word with high bits set: a contract may use them.
        XCTAssertNil(WalletConnectTokenCall.decode(Self.call("a9059cbb", dirtyAddress, Self.word(BigUInt(5)))))
        // A bool other than 0 or 1.
        XCTAssertNil(WalletConnectTokenCall.decode(Self.call("a22cb465", Self.word(recipient), Self.word(BigUInt(2)))))
        // Arguments cut short.
        XCTAssertNil(WalletConnectTokenCall.decode(Self.call("a9059cbb", Self.word(recipient))))
        // A selector the wallet does not know.
        XCTAssertNil(WalletConnectTokenCall.decode(Self.call("deadbeef", Self.word(recipient), Self.word(BigUInt(5)))))
        XCTAssertNil(WalletConnectTokenCall.decode(Data([0xA9, 0x05])))
    }

    // MARK: - EVM messages and typed data

    #if DEBUG
        func testPersonalSign_signsThePrefixedMessageWithAJSONRPCRecoveryId() async throws {
            let keystore = InMemoryKeychain()
            let wallet = try Fixtures.ethereumWallet(seed: 0x51, keystore: keystore)
            let blockchain = try Fixtures.ethereumBlockchain()
            let session = try Fixtures.session(approving: [(blockchain, wallet.addressHex)])
            let request = try Fixtures.request(
                method: .ethereumPersonalSign,
                params: "[\"0x48656c6c6f\", \"\(wallet.addressHex)\"]",
                chain: blockchain
            )
            let signingRequest = try await makePreparer()
                .prepare(request: request, session: session, wallets: [wallet.wallet], chains: [Fixtures.ethereumChain()])

            guard case let .ethereumMessage(message) = signingRequest.content else {
                return XCTFail("Expected a message")
            }
            XCTAssertEqual(message.text, "Hello")

            let signature = try await WalletConnectSignerImpl(policy: .enabledForTests, keystore: keystore)
                .sign(request: signingRequest)
                .get(String.self)

            let expected = try wallet.privateKey.sign(message: Array("\u{19}Ethereum Signed Message:\n5Hello".utf8))
            XCTAssertEqual(
                signature,
                (Data(expected.r) + Data(expected.s) + Data([UInt8(expected.v) + 27])).toHex(includePrefix: true)
            )
        }

        func testTypedData_signsTheEIP712DigestOfTheDomainAndMessage() async throws {
            let keystore = InMemoryKeychain()
            let wallet = try Fixtures.ethereumWallet(seed: 0x52, keystore: keystore)
            let blockchain = try Fixtures.ethereumBlockchain()
            let session = try Fixtures.session(approving: [(blockchain, wallet.addressHex)])
            let request = try Fixtures.request(
                method: .ethereumSignTypeDataV4,
                params: Self.jsonString([wallet.addressHex, Self.mailTypedData(chainId: 1)]),
                chain: blockchain
            )
            let signingRequest = try await makePreparer()
                .prepare(request: request, session: session, wallets: [wallet.wallet], chains: [Fixtures.ethereumChain()])

            guard case let .ethereumTypedData(typedData) = signingRequest.content else {
                return XCTFail("Expected typed data")
            }
            // The digest of the EIP-712 specification's example.
            XCTAssertEqual(
                typedData.signingInput.sha3(.keccak256).toHex(),
                "be609aee343fb3c4b28e1df9e632fca64fcfaede20f02e86244efddf30957bd2"
            )
            XCTAssertEqual(typedData.domainName, "Ether Mail")
            XCTAssertEqual(typedData.primaryType, "Mail")

            let signature = try await WalletConnectSignerImpl(policy: .enabledForTests, keystore: keystore)
                .sign(request: signingRequest)
                .get(String.self)
            let expected = try wallet.privateKey.sign(message: Array(typedData.signingInput))
            XCTAssertEqual(
                signature,
                (Data(expected.r) + Data(expected.s) + Data([UInt8(expected.v) + 27])).toHex(includePrefix: true)
            )
        }
    #endif

    func testTypedData_whenDomainChainIdIsAnotherNetwork_thenDeclines() async throws {
        await assertTypedData(Self.mailTypedData(chainId: 56), declinesWith: .networkMismatch)
    }

    func testTypedData_whenDomainChainIdIsNotANumber_thenDeclines() async throws {
        await assertTypedData(Self.mailTypedData(chainId: "one"), declinesWith: .unsupported)
    }

    func testTypedData_whenDomainChainIdIsHex_thenDeclinesBecauseTheHashWouldOmitIt() async throws {
        await assertTypedData(Self.mailTypedData(chainId: "0x1"), declinesWith: .unsupported)
    }

    func testTypedData_whenLegacyArrayFormat_thenDeclines() async throws {
        await assertTypedData([["type": "string", "name": "message", "value": "Hi"]], declinesWith: .unsupported)
    }

    func testTypedData_whenPrimaryTypeIsNotDefined_thenDeclines() async throws {
        var typedData = Self.mailTypedData(chainId: 1)
        typedData["primaryType"] = "Missing"
        await assertTypedData(typedData, declinesWith: .unsupported)
    }

    func testTypedData_readsTheSpenderAndAmountOfAPermit() async throws {
        let keystore = InMemoryKeychain()
        let wallet = try Fixtures.ethereumWallet(seed: 0x53, keystore: keystore)
        let blockchain = try Fixtures.ethereumBlockchain()
        let session = try Fixtures.session(approving: [(blockchain, wallet.addressHex)])
        let spender = "0x" + String(repeating: "5a", count: 20)
        let token = "0x" + String(repeating: "7b", count: 20)
        let permit: [String: Any] = [
            "types": [
                "EIP712Domain": [
                    ["name": "name", "type": "string"],
                    ["name": "chainId", "type": "uint256"],
                    ["name": "verifyingContract", "type": "address"]
                ],
                "Permit": [
                    ["name": "owner", "type": "address"],
                    ["name": "spender", "type": "address"],
                    ["name": "value", "type": "uint256"],
                    ["name": "nonce", "type": "uint256"],
                    ["name": "deadline", "type": "uint256"]
                ]
            ],
            "primaryType": "Permit",
            "domain": ["name": "Token", "chainId": 1, "verifyingContract": token],
            "message": [
                "owner": wallet.addressHex,
                "spender": spender,
                "value": "1000000",
                "nonce": 0,
                "deadline": 1_900_000_000
            ]
        ]
        let request = try Fixtures.request(
            method: .ethereumSignTypeDataV4,
            params: Self.jsonString([wallet.addressHex, permit]),
            chain: blockchain
        )

        let signingRequest = try await makePreparer()
            .prepare(request: request, session: session, wallets: [wallet.wallet], chains: [Fixtures.ethereumChain()])

        guard case let .ethereumTypedData(typedData) = signingRequest.content else {
            return XCTFail("Expected typed data")
        }
        XCTAssertEqual(
            typedData.allowance,
            WalletConnectTokenAllowance(
                token: try Data(hexStringSSF: token),
                spender: try Data(hexStringSSF: spender),
                amount: 1_000_000,
                deadline: 1_900_000_000
            )
        )
    }

    func testTypedData_readsADaiPermitAsUnlimitedUntilItsExpiry() async throws {
        let wallet = try Fixtures.ethereumWallet(seed: 0x55, keystore: InMemoryKeychain())
        let spender = "0x" + String(repeating: "5a", count: 20)
        let dai = "0x" + String(repeating: "6b", count: 20)
        let permit: [String: Any] = [
            "types": [
                "EIP712Domain": [
                    ["name": "name", "type": "string"],
                    ["name": "version", "type": "string"],
                    ["name": "chainId", "type": "uint256"],
                    ["name": "verifyingContract", "type": "address"]
                ],
                "Permit": [
                    ["name": "holder", "type": "address"],
                    ["name": "spender", "type": "address"],
                    ["name": "nonce", "type": "uint256"],
                    ["name": "expiry", "type": "uint256"],
                    ["name": "allowed", "type": "bool"]
                ]
            ],
            "primaryType": "Permit",
            "domain": ["name": "Dai Stablecoin", "version": "1", "chainId": 1, "verifyingContract": dai],
            "message": [
                "holder": wallet.addressHex,
                "spender": spender,
                "nonce": 0,
                "expiry": 1_900_000_000,
                "allowed": true
            ]
        ]

        let typedData = try await prepareTypedData(permit, wallet: wallet)

        XCTAssertEqual(
            typedData.allowance,
            WalletConnectTokenAllowance(
                token: try Data(hexStringSSF: dai),
                spender: try Data(hexStringSSF: spender),
                amount: BigUInt(2).power(256) - 1,
                deadline: 1_900_000_000
            )
        )
    }

    func testTypedData_whenTheDomainCarriesAChainIdItDoesNotDeclare_thenDeclines() async throws {
        // The chain id would be checked here but left out of the hash: the signature would work on every network.
        var typedData = Self.mailTypedData(chainId: 1)
        var types = try XCTUnwrap(typedData["types"] as? [String: Any])
        types["EIP712Domain"] = [
            ["name": "name", "type": "string"],
            ["name": "version", "type": "string"],
            ["name": "verifyingContract", "type": "address"]
        ]
        typedData["types"] = types

        await assertTypedData(typedData, declinesWith: .unsupported)
    }

    func testTypedData_whenTheDomainHasNoChainId_thenItIsMarkedAsValidOnAnyNetwork() async throws {
        var typedData = Self.mailTypedData(chainId: 1)
        var types = try XCTUnwrap(typedData["types"] as? [String: Any])
        types["EIP712Domain"] = [
            ["name": "name", "type": "string"],
            ["name": "version", "type": "string"],
            ["name": "verifyingContract", "type": "address"]
        ]
        typedData["types"] = types
        var domain = try XCTUnwrap(typedData["domain"] as? [String: Any])
        domain["chainId"] = nil
        typedData["domain"] = domain

        let prepared = try await prepareTypedData(
            typedData,
            wallet: try Fixtures.ethereumWallet(seed: 0x56, keystore: InMemoryKeychain())
        )

        XCTAssertTrue(prepared.isChainUnbound)
    }

    func testTypedData_whenTheDomainHasTheChainId_thenItIsBound() async throws {
        let prepared = try await prepareTypedData(
            Self.mailTypedData(chainId: 1),
            wallet: try Fixtures.ethereumWallet(seed: 0x57, keystore: InMemoryKeychain())
        )

        XCTAssertFalse(prepared.isChainUnbound)
    }

    func testTypedData_listsEverySignedFieldInTheOrderItsTypesDeclare() async throws {
        var typedData = Self.mailTypedData(chainId: 1)
        var message = try XCTUnwrap(typedData["message"] as? [String: Any])
        // Not declared, so not hashed: not shown either.
        message["note"] = "not signed"
        typedData["message"] = message

        let prepared = try await prepareTypedData(
            typedData,
            wallet: try Fixtures.ethereumWallet(seed: 0x58, keystore: InMemoryKeychain())
        )

        XCTAssertEqual(prepared.fields, [
            WalletConnectTypedDataField(path: "domain.name", value: "Ether Mail"),
            WalletConnectTypedDataField(path: "domain.version", value: "1"),
            WalletConnectTypedDataField(path: "domain.chainId", value: "1"),
            WalletConnectTypedDataField(
                path: "domain.verifyingContract",
                value: "0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC"
            ),
            WalletConnectTypedDataField(path: "message.from.name", value: "Cow"),
            WalletConnectTypedDataField(path: "message.from.wallet", value: "0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826"),
            WalletConnectTypedDataField(path: "message.to.name", value: "Bob"),
            WalletConnectTypedDataField(path: "message.to.wallet", value: "0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB"),
            WalletConnectTypedDataField(path: "message.contents", value: "Hello, Bob!")
        ])
    }

    func testTypedDataFields_listArraysByIndex() throws {
        let types: MessageTypes = [
            "EIP712Domain": [MessageTypeProperty(name: "name", type: "string")],
            "Batch": [MessageTypeProperty(name: "amounts", type: "uint256[]")]
        ]

        let fields = try WalletConnectTypedDataFields.flatten(
            domain: ["name": "Batcher"],
            message: ["amounts": (0 ..< 70).map { NSNumber(value: $0) }],
            types: types,
            primaryType: "Batch"
        )

        XCTAssertEqual(fields.count, 71)
        XCTAssertEqual(fields[1], WalletConnectTypedDataField(path: "message.amounts[0]", value: "0"))
        XCTAssertEqual(fields.last, WalletConnectTypedDataField(path: "message.amounts[69]", value: "69"))
    }

    func testTypedDataFields_whenThereAreMoreThanTheConfirmationShows_thenNothingIsCutButItIsRefused() {
        let types: MessageTypes = [
            "EIP712Domain": [MessageTypeProperty(name: "name", type: "string")],
            "Batch": [MessageTypeProperty(name: "amounts", type: "uint256[]")]
        ]
        let amounts = (0 ..< WalletConnectTypedDataFields.limit).map { NSNumber(value: $0) }

        XCTAssertThrowsError(try WalletConnectTypedDataFields.flatten(
            domain: ["name": "Batcher"],
            message: ["amounts": amounts],
            types: types,
            primaryType: "Batch"
        )) { error in
            XCTAssertEqual(error as? WalletConnectTypedDataFields.Problem, .tooLarge)
        }
    }

    func testTypedDataFields_whenNestedDeeperThanShown_thenItIsRefusedRatherThanDropped() {
        var types: MessageTypes = ["EIP712Domain": [MessageTypeProperty(name: "name", type: "string")]]
        var value: [String: Any] = ["leaf": "end"]
        types["Level0"] = [MessageTypeProperty(name: "leaf", type: "string")]
        for level in 1 ... WalletConnectTypedDataFields.maxDepth + 1 {
            types["Level\(level)"] = [MessageTypeProperty(name: "next", type: "Level\(level - 1)")]
            value = ["next": value]
        }

        XCTAssertThrowsError(try WalletConnectTypedDataFields.flatten(
            domain: ["name": "Deep"],
            message: value,
            types: types,
            primaryType: "Level\(WalletConnectTypedDataFields.maxDepth + 1)"
        )) { error in
            XCTAssertEqual(error as? WalletConnectTypedDataFields.Problem, .tooLarge)
        }
    }

    func testTypedDataFields_whenAValueDoesNotHaveItsDeclaredShape_thenItIsRefused() {
        let types: MessageTypes = [
            "EIP712Domain": [MessageTypeProperty(name: "name", type: "string")],
            "Order": [
                MessageTypeProperty(name: "maker", type: "Person"),
                MessageTypeProperty(name: "items", type: "uint256[]")
            ],
            "Person": [MessageTypeProperty(name: "wallet", type: "address")]
        ]

        // The hash reads a struct that is not an object as empty, and a lone value as a one-item array.
        XCTAssertThrowsError(try WalletConnectTypedDataFields.flatten(
            domain: [:],
            message: ["maker": "0x1111111111111111111111111111111111111111"],
            types: types,
            primaryType: "Order"
        )) { error in
            XCTAssertEqual(error as? WalletConnectTypedDataFields.Problem, .shapeMismatch(path: "message.maker"))
        }
        XCTAssertThrowsError(try WalletConnectTypedDataFields.flatten(
            domain: [:],
            message: ["items": "5"],
            types: types,
            primaryType: "Order"
        )) { error in
            XCTAssertEqual(error as? WalletConnectTypedDataFields.Problem, .shapeMismatch(path: "message.items"))
        }
    }

    func testTypedDataFields_findTheKeysTheTypesDoNotDeclareAtEveryLevel() {
        let types: MessageTypes = [
            "EIP712Domain": [MessageTypeProperty(name: "name", type: "string")],
            "Order": [
                MessageTypeProperty(name: "maker", type: "Person"),
                MessageTypeProperty(name: "items", type: "Person[]")
            ],
            "Person": [MessageTypeProperty(name: "wallet", type: "address")]
        ]

        let keys = WalletConnectTypedDataFields.undeclaredKeys(
            domain: ["name": "Shop", "salt": "0x01"],
            message: [
                "maker": ["wallet": "0x11", "nickname": "x"],
                "items": [["wallet": "0x22"], ["wallet": "0x33", "extra": 1]],
                "note": "not signed"
            ],
            types: types,
            primaryType: "Order"
        )

        XCTAssertEqual(keys, ["domain.salt", "message.items[1].extra", "message.maker.nickname", "message.note"])
    }

    func testTypedDataFieldText_writesNumbersInFullAndBooleansAsWords() {
        XCTAssertEqual(WalletConnectTypedDataFields.text(of: NSNumber(value: 1_900_000_000)), "1900000000")
        XCTAssertEqual(
            WalletConnectTypedDataFields.text(of: NSDecimalNumber(string: "123456789012345678901234567890")),
            "123456789012345678901234567890"
        )
        XCTAssertEqual(WalletConnectTypedDataFields.text(of: NSNumber(value: true)), "true")
        XCTAssertEqual(WalletConnectTypedDataFields.text(of: "text"), "text")
    }

    func testPermitAmount_readsDecimalHexStringsAndJSONIntegersButNothingRounded() {
        let maximum = "115792089237316195423570985008687907853269984665640564039457584007913129639935"
        XCTAssertEqual(WalletConnectTokenAllowance.amount(from: "1000000" as NSString), 1_000_000)
        XCTAssertEqual(WalletConnectTokenAllowance.amount(from: "0x10" as NSString), 16)
        XCTAssertEqual(WalletConnectTokenAllowance.amount(from: maximum as NSString), BigUInt(2).power(256) - 1)
        XCTAssertEqual(WalletConnectTokenAllowance.amount(from: NSNumber(value: UInt64.max)), BigUInt(UInt64.max))
        // The JSON parser keeps 38 digits of a longer number: the amount would be rounded.
        XCTAssertNil(WalletConnectTokenAllowance.amount(from: NSDecimalNumber(string: maximum)))
        XCTAssertNil(WalletConnectTokenAllowance.amount(from: NSNumber(value: 1.5)))
        XCTAssertNil(WalletConnectTokenAllowance.amount(from: NSNumber(value: -1)))
        XCTAssertNil(WalletConnectTokenAllowance.amount(from: NSNumber(value: true)))
    }

    func testPermit_whenTheAmountCannotBeRead_thenTheSpenderIsStillNamed() {
        let spender = Data(repeating: 0x5A, count: 20)
        let token = Data(repeating: 0x7B, count: 20)

        let allowance = WalletConnectTokenAllowance(
            primaryType: "Permit",
            message: ["spender": spender.toHex(includePrefix: true) as NSString, "value": NSNumber(value: 1.5)],
            types: Self.permitTypes(Self.eip2612Fields),
            verifyingContract: token
        )

        XCTAssertEqual(allowance, WalletConnectTokenAllowance(token: token, spender: spender, amount: nil))
    }

    func testPermit_isReadOnlyFromTheExactStandardDefinition() {
        let spender = Data(repeating: 0x5A, count: 20)
        let token = Data(repeating: 0x7B, count: 20)
        let message: [String: AnyObject] = [
            "spender": spender.toHex(includePrefix: true) as NSString,
            "value": "1000" as NSString,
            "deadline": "1900000000" as NSString
        ]

        XCTAssertEqual(
            WalletConnectTokenAllowance(
                primaryType: "Permit",
                message: message,
                types: Self.permitTypes(Self.eip2612Fields),
                verifyingContract: token
            )?.amount,
            1000
        )
        // An extra field, another order, another type or a missing token: not a permit the wallet reads.
        let variants: [[(String, String)]] = [
            Self.eip2612Fields + [("memo", "string")],
            Array(Self.eip2612Fields.reversed()),
            Self.eip2612Fields.map { $0.0 == "value" ? ($0.0, "string") : $0 }
        ]
        for fields in variants {
            XCTAssertNil(
                WalletConnectTokenAllowance(
                    primaryType: "Permit",
                    message: message,
                    types: Self.permitTypes(fields),
                    verifyingContract: token
                ),
                "\(fields)"
            )
        }
        XCTAssertNil(WalletConnectTokenAllowance(
            primaryType: "Permit",
            message: message,
            types: Self.permitTypes(Self.eip2612Fields),
            verifyingContract: nil
        ))
    }

    func testTypedData_whenAPermitCarriesDAIKeysItDoesNotDeclare_thenTheSignedPermitIsShown() async throws {
        // The review's case: an EIP-2612 permit for the unlimited amount with a far deadline, plus undeclared
        // `allowed: false` and `expiry: 0`. The hash ignores the extra keys, so what is signed is unlimited.
        let wallet = try Fixtures.ethereumWallet(seed: 0x59, keystore: InMemoryKeychain())
        let spender = "0x" + String(repeating: "5a", count: 20)
        let usdc = "0x" + String(repeating: "7c", count: 20)
        let maximum = "115792089237316195423570985008687907853269984665640564039457584007913129639935"
        var permit = Self.eip2612Permit(owner: wallet.addressHex, spender: spender, token: usdc, value: maximum)
        var message = try XCTUnwrap(permit["message"] as? [String: Any])
        message["allowed"] = false
        message["expiry"] = 0
        permit["message"] = message

        let typedData = try await prepareTypedData(permit, wallet: wallet)

        XCTAssertEqual(
            typedData.allowance,
            WalletConnectTokenAllowance(
                token: try Data(hexStringSSF: usdc),
                spender: try Data(hexStringSSF: spender),
                amount: BigUInt(2).power(256) - 1,
                deadline: 99_999_999_999
            )
        )
        XCTAssertEqual(typedData.unsignedKeys, ["message.allowed", "message.expiry"])
        XCTAssertFalse(typedData.fields.contains { $0.path == "message.allowed" || $0.path == "message.expiry" })
        XCTAssertTrue(typedData.fields.contains { $0.path == "message.value" && $0.value == maximum })
    }

    func testTypedData_domainValuesAreShownOnlyWhenTheDomainTypeDeclaresThem() async throws {
        let wallet = try Fixtures.ethereumWallet(seed: 0x5B, keystore: InMemoryKeychain())
        let spender = "0x" + String(repeating: "5a", count: 20)
        let usdc = "0x" + String(repeating: "7c", count: 20)
        var permit = Self.eip2612Permit(owner: wallet.addressHex, spender: spender, token: usdc, value: "1000")
        var types = try XCTUnwrap(permit["types"] as? [String: Any])
        // Neither the token contract nor the name is hashed.
        types["EIP712Domain"] = [["name": "chainId", "type": "uint256"]]
        permit["types"] = types

        let typedData = try await prepareTypedData(permit, wallet: wallet)

        XCTAssertNil(typedData.verifyingContract)
        XCTAssertNil(typedData.domainName)
        XCTAssertNil(typedData.allowance, "Without a hashed token contract the permit names no token")
        XCTAssertEqual(typedData.unsignedKeys, ["domain.name", "domain.verifyingContract"])
    }

    func testTypedData_whenAFieldDoesNotHaveItsDeclaredShape_thenDeclines() async throws {
        var typedData = Self.mailTypedData(chainId: 1)
        var message = try XCTUnwrap(typedData["message"] as? [String: Any])
        message["from"] = "Cow"
        typedData["message"] = message

        await assertTypedData(typedData, declinesWith: .unsupported)
    }

    func testTypedData_whenItHasMoreFieldsThanTheConfirmationShows_thenDeclines() async {
        let typedData: [String: Any] = [
            "types": [
                "EIP712Domain": [["name": "name", "type": "string"], ["name": "chainId", "type": "uint256"]],
                "Batch": [["name": "amounts", "type": "uint256[]"]]
            ],
            "primaryType": "Batch",
            "domain": ["name": "Batcher", "chainId": 1],
            "message": ["amounts": (0 ..< WalletConnectTypedDataFields.limit).map { String($0) }]
        ]

        await assertTypedData(typedData, declinesWith: .unsupported)
    }

    static let eip2612Fields = [
        ("owner", "address"), ("spender", "address"), ("value", "uint256"), ("nonce", "uint256"), ("deadline", "uint256")
    ]

    static func permitTypes(_ fields: [(String, String)]) -> MessageTypes {
        [
            "EIP712Domain": [
                MessageTypeProperty(name: "name", type: "string"),
                MessageTypeProperty(name: "verifyingContract", type: "address")
            ],
            "Permit": fields.map { MessageTypeProperty(name: $0.0, type: $0.1) }
        ]
    }

    static func eip2612Permit(owner: String, spender: String, token: String, value: String) -> [String: Any] {
        [
            "types": [
                "EIP712Domain": [
                    ["name": "name", "type": "string"],
                    ["name": "chainId", "type": "uint256"],
                    ["name": "verifyingContract", "type": "address"]
                ],
                "Permit": eip2612Fields.map { ["name": $0.0, "type": $0.1] }
            ],
            "primaryType": "Permit",
            "domain": ["name": "USD Coin", "chainId": 1, "verifyingContract": token],
            "message": [
                "owner": owner,
                "spender": spender,
                "value": value,
                "nonce": 0,
                "deadline": 99_999_999_999
            ]
        ]
    }

    // MARK: - Substrate messages

    func testBytesEnvelope_wrapsMessagesOnceLikePolkadotJs() {
        XCTAssertEqual(WalletConnectBytesEnvelope.wrap(Data("hello".utf8)), Data("<Bytes>hello</Bytes>".utf8))
        XCTAssertEqual(WalletConnectBytesEnvelope.wrap(Data("<Bytes>hello</Bytes>".utf8)), Data("<Bytes>hello</Bytes>".utf8))
        XCTAssertEqual(WalletConnectBytesEnvelope.wrap(Data()), Data("<Bytes></Bytes>".utf8))
        XCTAssertEqual(
            WalletConnectBytesEnvelope.wrap(Data("\u{19}Ethereum Signed Message:\n1a".utf8)),
            Data("<Bytes>\u{19}Ethereum Signed Message:\n1a</Bytes>".utf8)
        )
    }

    #if DEBUG
        func testPolkadotMessage_isSignedInsideTheBytesEnvelope() async throws {
            let keystore = InMemoryKeychain()
            let wallet = try Fixtures.substrateWallet(seed: 0x61, keystore: keystore)
            let blockchain = try Fixtures.westendBlockchain()
            let address = try wallet.accountId.toAddress(using: .substrate(42))
            let session = try Fixtures.session(approving: [(blockchain, address)])
            let rawMessage = "0x0400" + String(repeating: "ff", count: 32)
            let request = try Fixtures.request(
                method: .polkadotSignMessage,
                params: "{\"address\": \"\(address)\", \"message\": \"\(rawMessage)\"}",
                chain: blockchain
            )
            let signingRequest = try await makePreparer()
                .prepare(request: request, session: session, wallets: [wallet.wallet], chains: [Fixtures.westend()])

            let result = try await WalletConnectSignerImpl(policy: .enabledForTests, keystore: keystore)
                .sign(request: signingRequest)
                .get(WalletConnectPolkadotSignature.self)
            let signature = try SNSignature(rawData: Data(hexStringSSF: result.signature))
            let publicKey = try SNPublicKey(rawData: wallet.accountId)
            let message = try Data(hexStringSSF: rawMessage)
            let verifier = SNSignatureVerifier()

            XCTAssertTrue(
                verifier.verify(signature, forOriginalData: WalletConnectBytesEnvelope.wrap(message), using: publicKey)
            )
            XCTAssertFalse(verifier.verify(signature, forOriginalData: message, using: publicKey))
        }
    #endif

    // MARK: - Substrate transactions

    func testCompactEncoding_matchesSCALE() {
        XCTAssertEqual(PolkadotFixture.compact(0), Data([0x00]))
        XCTAssertEqual(PolkadotFixture.compact(5), Data([0x14]))
        XCTAssertEqual(PolkadotFixture.compact(69), Data([0x15, 0x01]))
        XCTAssertEqual(PolkadotFixture.compact(1_000_000_000_000), Data([0x07, 0x00, 0x10, 0xA5, 0xD4, 0xE8]))
    }

    func testPolkadotTransaction_decodesATransferAndQuotesTheFeeOfThatExtrinsic() async throws {
        let fixture = try PolkadotFixture()
        let runtime = WalletConnectRuntimeStub()
        runtime.coderFactory = fixture.coderFactory

        let signingRequest = try await fixture.prepare(runtime: runtime)

        guard case let .polkadotTransaction(extrinsic) = signingRequest.content else {
            return XCTFail("Expected a transaction")
        }
        XCTAssertEqual(extrinsic.call.moduleName, "Balances")
        XCTAssertEqual(extrinsic.call.callName, "transfer_keep_alive")
        XCTAssertEqual(extrinsic.transfer, WalletConnectSubstrateTransfer(recipient: fixture.recipient, amount: fixture.amount))
        XCTAssertEqual(extrinsic.fee, runtime.fee)
        XCTAssertEqual(extrinsic.nonce, 5)
        XCTAssertEqual(runtime.feeQueries.count, 1)
        XCTAssertNotNil(runtime.feeQueries.first?.range(of: fixture.callData), "The fee is quoted for the dApp's call")
    }

    #if DEBUG
        func testPolkadotTransaction_signsTheDAppsCallForTheCheckedRuntimeAndGenesis() async throws {
            let fixture = try PolkadotFixture()
            let runtime = WalletConnectRuntimeStub()
            runtime.coderFactory = fixture.coderFactory
            let signingRequest = try await fixture.prepare(runtime: runtime)

            let result = try await WalletConnectSignerImpl(
                policy: .enabledForTests,
                keystore: fixture.keystore,
                polkadotRuntime: runtime
            )
            .sign(request: signingRequest)
            .get(WalletConnectPolkadotSignature.self)

            let encoded = try Data(hexStringSSF: result.signature)
            XCTAssertEqual(encoded.first, 0x01, "An sr25519 MultiSignature")
            let signature = try SNSignature(rawData: Data(encoded.dropFirst()))

            // call ‖ immortal era ‖ nonce ‖ tip ‖ spec version ‖ transaction version ‖ genesis ‖ block hash
            let genesis = try Data(hexStringSSF: Fixtures.polkadotGenesis)
            var expectedPayload = fixture.callData
            expectedPayload.append(contentsOf: [0x00, 0x14, 0x00])
            expectedPayload.append(contentsOf: withUnsafeBytes(of: UInt32(9370).littleEndian, Array.init))
            expectedPayload.append(contentsOf: withUnsafeBytes(of: UInt32(20).littleEndian, Array.init))
            expectedPayload.append(genesis)
            expectedPayload.append(genesis)

            XCTAssertTrue(
                SNSignatureVerifier().verify(
                    signature,
                    forOriginalData: expectedPayload,
                    using: try SNPublicKey(rawData: fixture.wallet.accountId)
                )
            )
        }

        func testPolkadotTransaction_whenTheRuntimeChangesBeforeSigning_thenNothingIsSigned() async throws {
            let fixture = try PolkadotFixture()
            let runtime = WalletConnectRuntimeStub()
            runtime.coderFactory = fixture.coderFactory
            let signingRequest = try await fixture.prepare(runtime: runtime)

            runtime.coderFactory = try Fixtures.polkadotCoderFactory(specVersion: 9380)
            let signer = WalletConnectSignerImpl(policy: .enabledForTests, keystore: fixture.keystore, polkadotRuntime: runtime)

            await assertDeclines(try await signer.sign(request: signingRequest), with: .runtimeMismatch(chainName: "Polkadot"))
        }
    #endif

    func testPolkadotTransaction_whenGenesisHashIsAnotherChain_thenDeclines() async throws {
        let fixture = try PolkadotFixture(genesisHash: "0xb0a8d493285c2df73290dfb7e61f870f17b41801197a149ca93654499ea3dafe")
        let runtime = WalletConnectRuntimeStub()
        runtime.coderFactory = fixture.coderFactory

        await assertDeclines(try await fixture.prepare(runtime: runtime), with: .networkMismatch)
        XCTAssertTrue(runtime.feeQueries.isEmpty)
    }

    func testPolkadotTransaction_whenSpecVersionIsNotTheChainsRuntime_thenDeclines() async throws {
        let fixture = try PolkadotFixture(specVersion: "0x0000249b")
        let runtime = WalletConnectRuntimeStub()
        runtime.coderFactory = fixture.coderFactory

        await assertDeclines(try await fixture.prepare(runtime: runtime), with: .runtimeMismatch(chainName: "Polkadot"))
    }

    func testPolkadotTransaction_whenTransactionVersionIsNotTheChainsRuntime_thenDeclines() async throws {
        let fixture = try PolkadotFixture(transactionVersion: "0x00000015")
        let runtime = WalletConnectRuntimeStub()
        runtime.coderFactory = fixture.coderFactory

        await assertDeclines(try await fixture.prepare(runtime: runtime), with: .runtimeMismatch(chainName: "Polkadot"))
    }

    func testPolkadotTransaction_whenABatchIsTooLargeToShowInFull_thenDeclines() async throws {
        let fixture = try PolkadotFixture(call: Self.batchOfRemarks(WalletConnectSubstrateCallText.maxCalls + 1))
        let runtime = WalletConnectRuntimeStub()
        runtime.coderFactory = fixture.coderFactory

        await assertDeclines(try await fixture.prepare(runtime: runtime), with: .unsupported)
        XCTAssertTrue(runtime.feeQueries.isEmpty, "Declined before anything else")
    }

    func testPolkadotTransaction_whenABatchFits_thenItIsPreparedWithEveryCall() async throws {
        let fixture = try PolkadotFixture(call: Self.batchOfRemarks(3))
        let runtime = WalletConnectRuntimeStub()
        runtime.coderFactory = fixture.coderFactory

        let signingRequest = try await fixture.prepare(runtime: runtime)

        guard case let .polkadotTransaction(extrinsic) = signingRequest.content else {
            return XCTFail("Expected a transaction")
        }
        XCTAssertEqual(extrinsic.call.callName, "batch_all")
        XCTAssertNil(extrinsic.transfer)
        XCTAssertEqual(WalletConnectSubstrateCallText.innerCalls(of: extrinsic.call).count, 3)
        let text = WalletConnectSubstrateCallText(address: { _ in nil }, nativeAmount: { _ in nil })
            .text(forArgumentsOf: extrinsic.call)
        XCTAssertTrue(text.contains("remark: [104, 105]"), text)
    }

    private static func batchOfRemarks(_ count: Int) throws -> RuntimeCall<JSON> {
        // `remark: Vec<u8>` takes its bytes as a list of numbers.
        let remark = RuntimeCall(
            moduleName: "System",
            callName: "remark",
            args: JSON.dictionaryValue(["remark": .arrayValue([.stringValue("104"), .stringValue("105")])])
        )
        let remarkJSON = try remark.toScaleCompatibleJSON()
        return RuntimeCall(
            moduleName: "Utility",
            callName: "batch_all",
            args: JSON.dictionaryValue(["calls": .arrayValue(Array(repeating: remarkJSON, count: count))])
        )
    }

    func testPolkadotTransaction_whenTheCallHasExtraBytes_thenDeclines() async throws {
        let fixture = try PolkadotFixture(callSuffix: Data([0x00]))
        let runtime = WalletConnectRuntimeStub()
        runtime.coderFactory = fixture.coderFactory

        await assertDeclines(try await fixture.prepare(runtime: runtime), with: .unsupported)
    }

    func testPolkadotTransaction_whenPayloadNamesAnotherAccount_thenDeclines() async throws {
        let fixture = try PolkadotFixture(payloadAddressSeed: 0x7F)
        let runtime = WalletConnectRuntimeStub()
        runtime.coderFactory = fixture.coderFactory

        await assertDeclines(try await fixture.prepare(runtime: runtime), with: .accountNotApproved)
    }

    func testPolkadotTransaction_whenNonceDoesNotFitTheExtrinsic_thenDeclines() async throws {
        let fixture = try PolkadotFixture(nonce: "0x0100000000")
        let runtime = WalletConnectRuntimeStub()
        runtime.coderFactory = fixture.coderFactory

        await assertDeclines(try await fixture.prepare(runtime: runtime), with: .unsupported)
    }

    // MARK: - Helpers

    private func makePreparer(quoting: WalletConnectQuotingStub = WalletConnectQuotingStub()) -> WalletConnectRequestPreparer {
        WalletConnectRequestPreparer(
            ethereumPreparer: WalletConnectEthereumRequestPreparer(quotingFactory: { _ in quoting }),
            polkadotPreparer: WalletConnectPolkadotRequestPreparer(runtime: WalletConnectRuntimeStub())
        )
    }

    private func prepareTransaction(
        wallet: WalletConnectTestFixtures.EthereumWallet,
        fields: String,
        quoting: WalletConnectQuotingStub
    ) async throws -> WalletConnectSigningRequest {
        let blockchain = try Fixtures.ethereumBlockchain()
        let session = try Fixtures.session(approving: [(blockchain, wallet.addressHex)])
        let request = try Fixtures.request(
            method: .ethereumSendTransaction,
            params: "[{\"from\": \"\(wallet.addressHex)\", \(fields)}]",
            chain: blockchain
        )
        return try await makePreparer(quoting: quoting)
            .prepare(request: request, session: session, wallets: [wallet.wallet], chains: [Fixtures.ethereumChain()])
    }

    private func assertTypedData(
        _ typedData: Any,
        declinesWith expected: WalletConnectRequestError,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            let keystore = InMemoryKeychain()
            let wallet = try Fixtures.ethereumWallet(seed: 0x54, keystore: keystore)
            let blockchain = try Fixtures.ethereumBlockchain()
            let session = try Fixtures.session(approving: [(blockchain, wallet.addressHex)])
            let request = try Fixtures.request(
                method: .ethereumSignTypeDataV4,
                params: Self.jsonString([wallet.addressHex, typedData]),
                chain: blockchain
            )
            await assertDeclines(
                try await makePreparer()
                    .prepare(request: request, session: session, wallets: [wallet.wallet], chains: [Fixtures.ethereumChain()]),
                with: expected,
                file: file,
                line: line
            )
        } catch {
            XCTFail("Fixture failed: \(error)", file: file, line: line)
        }
    }

    private func prepareTypedData(
        _ typedData: [String: Any],
        wallet: WalletConnectTestFixtures.EthereumWallet
    ) async throws -> WalletConnectTypedData {
        let blockchain = try Fixtures.ethereumBlockchain()
        let session = try Fixtures.session(approving: [(blockchain, wallet.addressHex)])
        let request = try Fixtures.request(
            method: .ethereumSignTypeDataV4,
            params: Self.jsonString([wallet.addressHex, typedData]),
            chain: blockchain
        )
        let signingRequest = try await makePreparer()
            .prepare(request: request, session: session, wallets: [wallet.wallet], chains: [Fixtures.ethereumChain()])
        guard case let .ethereumTypedData(prepared) = signingRequest.content else {
            throw WalletConnectRequestError.unsupported
        }
        return prepared
    }

    /// Calldata: a selector in hex, then 32-byte words.
    static func call(_ selector: String, _ words: Data...) -> Data {
        words.reduce((try? Data(hexStringSSF: selector)) ?? Data(), +)
    }

    static func word(_ address: Data) -> Data {
        Data(count: 32 - address.count) + address
    }

    static func word(_ number: BigUInt) -> Data {
        let bytes = number.serialize()
        return Data(count: 32 - bytes.count) + bytes
    }

    static func jsonString(_ parameters: [Any]) -> String {
        let normalized = parameters.map { parameter -> Any in
            guard !(parameter is String) else {
                return parameter
            }
            // Typed data travels as a JSON string inside the params array.
            let data = (try? JSONSerialization.data(withJSONObject: parameter, options: [.sortedKeys])) ?? Data()
            return String(data: data, encoding: .utf8) ?? ""
        }
        let data = (try? JSONSerialization.data(withJSONObject: normalized)) ?? Data()
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    static func mailTypedData(chainId: Any) -> [String: Any] {
        [
            "types": [
                "EIP712Domain": [
                    ["name": "name", "type": "string"],
                    ["name": "version", "type": "string"],
                    ["name": "chainId", "type": "uint256"],
                    ["name": "verifyingContract", "type": "address"]
                ],
                "Person": [
                    ["name": "name", "type": "string"],
                    ["name": "wallet", "type": "address"]
                ],
                "Mail": [
                    ["name": "from", "type": "Person"],
                    ["name": "to", "type": "Person"],
                    ["name": "contents", "type": "string"]
                ]
            ],
            "primaryType": "Mail",
            "domain": [
                "name": "Ether Mail",
                "version": "1",
                "chainId": chainId,
                "verifyingContract": "0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC"
            ],
            "message": [
                "from": ["name": "Cow", "wallet": "0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826"],
                "to": ["name": "Bob", "wallet": "0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB"],
                "contents": "Hello, Bob!"
            ]
        ]
    }
}

/// A Polkadot `Balances.transfer_keep_alive` request for the bundled 9370 runtime.
private struct PolkadotFixture {
    let keystore = InMemoryKeychain()
    let wallet: WalletConnectTestFixtures.SubstrateWallet
    let coderFactory: RuntimeCoderFactoryProtocol
    let recipient = Data(repeating: 0x42, count: 32)
    let amount = BigUInt(1_000_000_000_000)
    let callData: Data
    let request: Request
    let session: Session

    init(
        genesisHash: String = "0x" + WalletConnectTestFixtures.polkadotGenesis,
        specVersion: String = "0x0000249a",
        transactionVersion: String = "0x00000014",
        nonce: String = "0x00000005",
        callSuffix: Data = Data(),
        payloadAddressSeed: UInt8? = nil,
        call: RuntimeCall<JSON>? = nil
    ) throws {
        wallet = try WalletConnectTestFixtures.substrateWallet(seed: 0x71, keystore: keystore)
        coderFactory = try WalletConnectTestFixtures.polkadotCoderFactory()

        // The call is written out byte by byte so the app's decoding is checked against SCALE
        // itself rather than against its own encoder.
        let metadata = coderFactory.metadata
        let moduleIndex = try XCTUnwrap(metadata.getModuleIndex("Balances"))
        let callIndex = try XCTUnwrap(metadata.getCallIndex(in: "Balances", callName: "transfer_keep_alive"))
        let destinationType = try XCTUnwrap(
            metadata.getFunction(from: "Balances", with: "transfer_keep_alive")?.arguments.first?.type
        )
        // `MultiAddress::Id` is variant 0; a plain `AccountId32` has no variant byte.
        let destination = destinationType.contains("MultiAddress") ? Data([0x00]) + recipient : recipient
        if let call = call {
            // Another call, encoded with the runtime's own encoder.
            let encoder = coderFactory.createEncoder()
            try encoder.append(json: call.toScaleCompatibleJSON(), type: GenericType.call.name)
            callData = try encoder.encode()
        } else {
            callData = Data([moduleIndex, callIndex]) + destination + Self.compact(amount)
        }

        let address = try wallet.accountId.toAddress(using: .substrate(0))
        let payloadAddress = try payloadAddressSeed.map {
            try SNKeyFactory().createKeypair(fromSeed: Data(repeating: $0, count: 32)).publicKey().rawData().toAddress(using: .substrate(0))
        } ?? address
        let blockchain = try WalletConnectTestFixtures.polkadotBlockchain()
        session = try WalletConnectTestFixtures.session(approving: [(blockchain, address)])

        let payload: [String: Any] = [
            "address": payloadAddress,
            "blockHash": genesisHash,
            "blockNumber": "0x00000000",
            "era": "0x00",
            "genesisHash": genesisHash,
            "method": (callData + callSuffix).toHex(includePrefix: true),
            "nonce": nonce,
            "signedExtensions": ["CheckSpecVersion", "CheckTxVersion", "CheckGenesis", "CheckMortality", "CheckNonce"],
            "specVersion": specVersion,
            "tip": "0x00000000000000000000000000000000",
            "transactionVersion": transactionVersion,
            "version": 4
        ]
        let params = try JSONSerialization.data(withJSONObject: ["address": address, "transactionPayload": payload])
        request = try WalletConnectTestFixtures.request(
            method: .polkadotSignTransaction,
            params: String(decoding: params, as: UTF8.self),
            chain: blockchain
        )
    }

    /// SCALE compact encoding.
    static func compact(_ value: BigUInt) -> Data {
        if value < BigUInt(1) << 6 {
            return Data([UInt8(value) << 2])
        }
        if value < BigUInt(1) << 14 {
            let encoded = UInt16(value) << 2 | 0b01
            return Data([UInt8(encoded & 0xFF), UInt8(encoded >> 8)])
        }
        if value < BigUInt(1) << 30 {
            let encoded = (UInt32(value) << 2 | 0b10).littleEndian
            return withUnsafeBytes(of: encoded) { Data($0) }
        }
        let littleEndian = Array(value.serialize().reversed())
        return Data([UInt8((littleEndian.count - 4) << 2 | 0b11)]) + Data(littleEndian)
    }

    func prepare(runtime: WalletConnectRuntimeStub) async throws -> WalletConnectSigningRequest {
        try await WalletConnectRequestPreparer(
            ethereumPreparer: WalletConnectEthereumRequestPreparer(quotingFactory: { _ in WalletConnectQuotingStub() }),
            polkadotPreparer: WalletConnectPolkadotRequestPreparer(runtime: runtime)
        )
        .prepare(request: request, session: session, wallets: [wallet.wallet], chains: [WalletConnectTestFixtures.polkadot()])
    }
}

/// Fails unless `expression` throws `expected`.
func assertDeclines<T>(
    _ expression: @autoclosure () async throws -> T,
    with expected: WalletConnectRequestError,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("Expected \(expected), but the request was accepted", file: file, line: line)
    } catch {
        XCTAssertEqual(error as? WalletConnectRequestError, expected, "\(error)", file: file, line: line)
    }
}
