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
                amount: 1_000_000
            )
        )
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
        payloadAddressSeed: UInt8? = nil
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
        callData = Data([moduleIndex, callIndex]) + destination + Self.compact(amount)

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
