@testable import fearless
import XCTest

final class SolanaTransferTransactionBuilderTests: XCTestCase {
    func testBuildsCanonicalLegacySystemTransferTransactionEnvelope() throws {
        let sender = try SolanaKeyDerivation.deriveAccount(mnemonic: Self.mnemonic).address
        let unsigned = try SolanaTransferTransactionBuilder.buildNativeTransfer(
            senderAddress: " \(sender) ",
            recipientAddress: " \(Self.recipient) ",
            lamports: 123_456_789,
            recentBlockhash: " \(Self.blockhash) "
        )
        let parsed = try SolanaTransactionSigner.parseSerializedTransaction(unsigned.transaction)

        XCTAssertEqual(unsigned.senderAddress, sender)
        XCTAssertEqual(unsigned.recipientAddress, Self.recipient)
        XCTAssertEqual(unsigned.recentBlockhash, Self.blockhash)
        XCTAssertEqual(unsigned.messageBase64, parsed.messageBytes.base64EncodedString())
        XCTAssertEqual(parsed.requiredSignatures, 1)
        XCTAssertEqual(parsed.readonlySignedAccounts, 0)
        XCTAssertEqual(parsed.readonlyUnsignedAccounts, 1)
        XCTAssertEqual(parsed.accountKeys, [sender, Self.recipient, SolanaTransferTransactionBuilder.systemProgramAddress])
        XCTAssertEqual(parsed.recentBlockhash, Self.blockhash)
        XCTAssertEqual(parsed.instructionCount, 1)
        XCTAssertEqual(parsed.signatureCount, 1)
        XCTAssertEqual(unsigned.transaction.subdata(in: 1 ..< 65), Data(repeating: 0, count: 64))
        XCTAssertTransferInstruction(unsigned.message, lamports: 123_456_789)
    }

    func testRejectsMalformedTransferParameters() {
        assertTransferError(.invalidLamports) {
            _ = try SolanaTransferTransactionBuilder.buildNativeTransfer(
                senderAddress: Self.sender,
                recipientAddress: Self.recipient,
                lamports: 0,
                recentBlockhash: Self.blockhash
            )
        }
        assertTransferError(.invalidSender) {
            _ = try SolanaTransferTransactionBuilder.buildNativeTransfer(
                senderAddress: "not-base58",
                recipientAddress: Self.recipient,
                lamports: 1,
                recentBlockhash: Self.blockhash
            )
        }
        assertTransferError(.invalidRecipient) {
            _ = try SolanaTransferTransactionBuilder.buildNativeTransfer(
                senderAddress: Self.sender,
                recipientAddress: "O0Il",
                lamports: 1,
                recentBlockhash: Self.blockhash
            )
        }
        assertTransferError(.invalidRecentBlockhash) {
            _ = try SolanaTransferTransactionBuilder.buildNativeTransfer(
                senderAddress: Self.sender,
                recipientAddress: Self.recipient,
                lamports: 1,
                recentBlockhash: "111"
            )
        }
    }

    func testBuildsCanonicalSPLTokenTransferCheckedTransactionEnvelope() throws {
        let unsigned = try SolanaTransferTransactionBuilder.buildTokenTransferChecked(
            ownerAddress: Self.owner,
            sourceTokenAccount: Self.sourceTokenAccount,
            destinationTokenAccount: Self.destinationTokenAccount,
            mintAddress: Self.mint,
            rawAmount: 1_234_567,
            decimals: 6,
            recentBlockhash: Self.blockhash
        )
        let parsed = try SolanaTransactionSigner.parseSerializedTransaction(unsigned.transaction)

        XCTAssertEqual(unsigned.ownerAddress, Self.owner)
        XCTAssertEqual(unsigned.sourceTokenAccount, Self.sourceTokenAccount)
        XCTAssertEqual(unsigned.destinationTokenAccount, Self.destinationTokenAccount)
        XCTAssertEqual(unsigned.mintAddress, Self.mint)
        XCTAssertEqual(unsigned.tokenProgram, .splToken)
        XCTAssertEqual(parsed.requiredSignatures, 1)
        XCTAssertEqual(parsed.readonlySignedAccounts, 0)
        XCTAssertEqual(parsed.readonlyUnsignedAccounts, 2)
        XCTAssertEqual(
            parsed.accountKeys,
            [
                Self.owner,
                Self.sourceTokenAccount,
                Self.destinationTokenAccount,
                Self.mint,
                SolanaTransferTransactionBuilder.splTokenProgramAddress
            ]
        )
        XCTAssertEqual(parsed.instructionCount, 1)
        XCTAssertEqual(unsigned.transaction.subdata(in: 1 ..< 65), Data(repeating: 0, count: 64))
        XCTAssertTokenTransferCheckedInstruction(
            unsigned.message,
            accountCount: 5,
            programIndex: 4,
            accountIndexes: [1, 3, 2, 0],
            amount: 1_234_567,
            decimals: 6
        )
    }

    func testBuildsToken2022TransferCheckedWithExtensionExtraAccountsInInstructionOrder() throws {
        let unsigned = try SolanaTransferTransactionBuilder.buildTokenTransferChecked(
            ownerAddress: Self.owner,
            sourceTokenAccount: Self.sourceTokenAccount,
            destinationTokenAccount: Self.destinationTokenAccount,
            mintAddress: Self.mint,
            rawAmount: Int64.max,
            decimals: 255,
            recentBlockhash: Self.blockhash,
            tokenProgram: .token2022,
            extraAccounts: [
                SolanaTokenTransferExtraAccount(address: Self.extraReadonlyAccount),
                SolanaTokenTransferExtraAccount(address: Self.extraWritableAccount, isWritable: true)
            ]
        )
        let parsed = try SolanaTransactionSigner.parseSerializedTransaction(unsigned.transaction)

        XCTAssertEqual(unsigned.tokenProgram, .token2022)
        XCTAssertEqual(parsed.readonlySignedAccounts, 0)
        XCTAssertEqual(parsed.readonlyUnsignedAccounts, 3)
        XCTAssertEqual(
            parsed.accountKeys,
            [
                Self.owner,
                Self.sourceTokenAccount,
                Self.destinationTokenAccount,
                Self.extraWritableAccount,
                Self.mint,
                SolanaTransferTransactionBuilder.token2022ProgramAddress,
                Self.extraReadonlyAccount
            ]
        )
        XCTAssertTokenTransferCheckedInstruction(
            unsigned.message,
            accountCount: 7,
            programIndex: 5,
            accountIndexes: [1, 4, 2, 0, 6, 3],
            amount: Int64.max,
            decimals: 255
        )
    }

    func testBuildsIdempotentAssociatedTokenAccountCreateWithPayerWalletDeduplicated() throws {
        let unsigned = try SolanaTransferTransactionBuilder.buildCreateAssociatedTokenAccount(
            fundingAddress: Self.owner,
            walletAddress: Self.owner,
            mintAddress: Self.mint,
            recentBlockhash: Self.blockhash
        )
        let parsed = try SolanaTransactionSigner.parseSerializedTransaction(unsigned.transaction)

        XCTAssertEqual(unsigned.fundingAddress, Self.owner)
        XCTAssertEqual(unsigned.walletAddress, Self.owner)
        XCTAssertEqual(unsigned.associatedTokenAccount, Self.ownerSPLAssociatedTokenAccount)
        XCTAssertEqual(unsigned.tokenProgram, .splToken)
        XCTAssertEqual(parsed.requiredSignatures, 1)
        XCTAssertEqual(parsed.readonlySignedAccounts, 0)
        XCTAssertEqual(parsed.readonlyUnsignedAccounts, 4)
        XCTAssertEqual(
            parsed.accountKeys,
            [
                Self.owner,
                Self.ownerSPLAssociatedTokenAccount,
                Self.mint,
                SolanaTransferTransactionBuilder.systemProgramAddress,
                SolanaTransferTransactionBuilder.splTokenProgramAddress,
                SolanaTransferTransactionBuilder.associatedTokenProgramAddress
            ]
        )
        XCTAssertAssociatedTokenCreateInstruction(
            unsigned.message,
            accountCount: 6,
            programIndex: 5,
            accountIndexes: [0, 1, 0, 2, 3, 4],
            discriminator: 1
        )
    }

    func testBuildsToken2022AssociatedTokenAccountCreateWithSeparatePayerAndCreateDiscriminator() throws {
        let unsigned = try SolanaTransferTransactionBuilder.buildCreateAssociatedTokenAccount(
            fundingAddress: Self.sender,
            walletAddress: Self.owner,
            associatedTokenAccount: Self.ownerToken2022AssociatedTokenAccount,
            mintAddress: Self.mint,
            recentBlockhash: Self.blockhash,
            tokenProgram: .token2022,
            instruction: .create
        )
        let parsed = try SolanaTransactionSigner.parseSerializedTransaction(unsigned.transaction)

        XCTAssertEqual(unsigned.tokenProgram, .token2022)
        XCTAssertEqual(parsed.readonlyUnsignedAccounts, 5)
        XCTAssertEqual(
            parsed.accountKeys,
            [
                Self.sender,
                Self.ownerToken2022AssociatedTokenAccount,
                Self.owner,
                Self.mint,
                SolanaTransferTransactionBuilder.systemProgramAddress,
                SolanaTransferTransactionBuilder.token2022ProgramAddress,
                SolanaTransferTransactionBuilder.associatedTokenProgramAddress
            ]
        )
        XCTAssertAssociatedTokenCreateInstruction(
            unsigned.message,
            accountCount: 7,
            programIndex: 6,
            accountIndexes: [0, 1, 2, 3, 4, 5],
            discriminator: 0
        )
    }

    func testBuildsTokenSendWithIdempotentAssociatedTokenAccountCreateThenTransferChecked() throws {
        let unsigned = try SolanaTransferTransactionBuilder.buildTokenSendChecked(
            ownerAddress: Self.owner,
            sourceTokenAccount: Self.sourceTokenAccount,
            mintAddress: Self.mint,
            rawAmount: 99000,
            decimals: 8,
            recentBlockhash: Self.blockhash,
            tokenProgram: .token2022,
            extraAccounts: [
                SolanaTokenTransferExtraAccount(address: Self.extraReadonlyAccount),
                SolanaTokenTransferExtraAccount(address: Self.extraWritableAccount, isWritable: true)
            ],
            destinationWalletAddress: Self.destinationWallet
        )
        let parsed = try SolanaTransactionSigner.parseSerializedTransaction(unsigned.transaction)

        XCTAssertTrue(unsigned.createsDestinationAssociatedTokenAccount)
        XCTAssertEqual(unsigned.destinationWalletAddress, Self.destinationWallet)
        XCTAssertEqual(unsigned.destinationTokenAccount, Self.destinationWalletToken2022AssociatedTokenAccount)
        XCTAssertEqual(unsigned.tokenProgram, .token2022)
        XCTAssertEqual(parsed.requiredSignatures, 1)
        XCTAssertEqual(parsed.readonlySignedAccounts, 0)
        XCTAssertEqual(parsed.readonlyUnsignedAccounts, 6)
        XCTAssertEqual(
            parsed.accountKeys,
            [
                Self.owner,
                Self.sourceTokenAccount,
                Self.destinationWalletToken2022AssociatedTokenAccount,
                Self.extraWritableAccount,
                Self.destinationWallet,
                Self.mint,
                SolanaTransferTransactionBuilder.systemProgramAddress,
                SolanaTransferTransactionBuilder.token2022ProgramAddress,
                SolanaTransferTransactionBuilder.associatedTokenProgramAddress,
                Self.extraReadonlyAccount
            ]
        )
        XCTAssertEqual(parsed.instructionCount, 2)
        XCTAssertEqual(unsigned.transaction.subdata(in: 1 ..< 65), Data(repeating: 0, count: 64))
        XCTAssertTokenSendWithAssociatedAccountCreateInstructions(
            unsigned.message,
            accountCount: 10,
            associatedProgramIndex: 8,
            associatedAccountIndexes: [0, 2, 4, 5, 6, 7],
            associatedDiscriminator: 1,
            tokenProgramIndex: 7,
            tokenAccountIndexes: [1, 5, 2, 0, 9, 3],
            amount: 99000,
            decimals: 8
        )
    }

    // MARK: - Priority fee (IOSUX-4)

    func testNativeTransferWithComputeBudgetPutsLimitThenPriceBeforeTheTransfer() throws {
        let unsigned = try SolanaTransferTransactionBuilder.buildNativeTransfer(
            senderAddress: Self.sender,
            recipientAddress: Self.recipient,
            lamports: 123_456_789,
            recentBlockhash: Self.blockhash,
            computeBudget: SolanaComputeBudget(unitLimit: 2000, unitPriceMicroLamports: 1000)
        )
        let parsed = try SolanaTransactionSigner.parseSerializedTransaction(unsigned.transaction)

        XCTAssertEqual(parsed.readonlyUnsignedAccounts, 2)
        XCTAssertEqual(parsed.accountKeys, [
            Self.sender,
            Self.recipient,
            SolanaTransferTransactionBuilder.systemProgramAddress,
            SolanaTransferTransactionBuilder.computeBudgetProgramAddress
        ])
        XCTAssertEqual(parsed.instructionCount, 3)
        var expected = Data([3])
        // SetComputeUnitLimit(2_000): program 3, no accounts, [2, u32 LE].
        expected.append(contentsOf: [3, 0, 5, 2, 0xD0, 0x07, 0, 0])
        // SetComputeUnitPrice(1_000 micro-lamports): program 3, no accounts, [3, u64 LE].
        expected.append(contentsOf: [3, 0, 9, 3, 0xE8, 0x03, 0, 0, 0, 0, 0, 0])
        // System transfer: program 2, accounts [0, 1], [2 as u32 LE, lamports as u64 LE].
        expected.append(contentsOf: [2, 2, 0, 1, 12, 2, 0, 0, 0])
        expected.append(contentsOf: withUnsafeBytes(of: UInt64(123_456_789).littleEndian, Array.init))
        XCTAssertEqual(unsigned.message.suffix(expected.count), expected)
        XCTAssertEqual(unsigned.message.count, 3 + 1 + 4 * 32 + 32 + expected.count)
    }

    func testZeroPriceSetsOnlyTheUnitLimit() throws {
        let unsigned = try SolanaTransferTransactionBuilder.buildNativeTransfer(
            senderAddress: Self.sender,
            recipientAddress: Self.recipient,
            lamports: 1,
            recentBlockhash: Self.blockhash,
            computeBudget: SolanaComputeBudget(unitLimit: 2000, unitPriceMicroLamports: 0)
        )

        XCTAssertEqual(try SolanaTransactionSigner.parseSerializedTransaction(unsigned.transaction).instructionCount, 2)
    }

    func testTokenSendWithComputeBudgetKeepsTheBudgetProgramReadonlyAndFirst() throws {
        let unsigned = try SolanaTransferTransactionBuilder.buildTokenSendChecked(
            ownerAddress: Self.sender,
            sourceTokenAccount: Self.sourceTokenAccount,
            mintAddress: Self.mint,
            rawAmount: 1_000_000,
            decimals: 6,
            recentBlockhash: Self.blockhash,
            destinationWalletAddress: Self.destinationWallet,
            computeBudget: SolanaComputeBudget(unitLimit: 100_000, unitPriceMicroLamports: 2_000_000)
        )
        let parsed = try SolanaTransactionSigner.parseSerializedTransaction(unsigned.transaction)
        let budgetIndex = try XCTUnwrap(parsed.accountKeys.firstIndex(of: SolanaTransferTransactionBuilder.computeBudgetProgramAddress))

        XCTAssertTrue(unsigned.createsDestinationAssociatedTokenAccount)
        XCTAssertEqual(parsed.instructionCount, 4)
        XCTAssertGreaterThanOrEqual(budgetIndex, parsed.accountKeys.count - parsed.readonlyUnsignedAccounts, "Read-only")
        let instructions = unsigned.message.suffix(from: unsigned.message.startIndex + 3 + 1 + parsed.accountKeys.count * 32 + 32)
        XCTAssertEqual(Array(instructions.prefix(9)), [4, UInt8(budgetIndex), 0, 5, 2, 0xA0, 0x86, 0x01, 0])
    }

    func testPriorityFeeIsRoundedUpToWholeLamports() {
        XCTAssertEqual(SolanaComputeBudget(unitLimit: 2000, unitPriceMicroLamports: 1000).priorityFeeLamports, 2)
        XCTAssertEqual(SolanaComputeBudget(unitLimit: 100_000, unitPriceMicroLamports: 2_000_000).priorityFeeLamports, 200_000)
        XCTAssertEqual(SolanaComputeBudget(unitLimit: 1, unitPriceMicroLamports: 1).priorityFeeLamports, 1)
        XCTAssertEqual(SolanaComputeBudget(unitLimit: 2000, unitPriceMicroLamports: 0).priorityFeeLamports, 0)
    }

    func testPriorityFeeFollowsRecentFeesWithinBounds() {
        XCTAssertEqual(SolanaPriorityFeePolicy.unitPrice(recentFees: []), 1000, "A quiet cluster still gets a price")
        XCTAssertEqual(SolanaPriorityFeePolicy.unitPrice(recentFees: [0, 0, 0, 0]), 1000)
        XCTAssertEqual(SolanaPriorityFeePolicy.unitPrice(recentFees: Array(1 ... 100).map { Int64($0 * 1000) }), 76000)
        XCTAssertEqual(SolanaPriorityFeePolicy.unitPrice(recentFees: [50_000_000]), 2_000_000, "A spike is capped")
        XCTAssertEqual(SolanaPriorityFeePolicy.unitPrice(recentFees: [-5, 3000]), 3000)
        // The cap bounds the priority fee of the largest transfer at 0.0002 SOL.
        let largest = SolanaComputeBudget(
            unitLimit: SolanaPriorityFeePolicy.unitLimit(for: .tokenTransferOpeningAccount),
            unitPriceMicroLamports: SolanaPriorityFeePolicy.maximumUnitPriceMicroLamports
        )
        XCTAssertEqual(largest.priorityFeeLamports, 200_000)
    }

    func testDerivesAssociatedTokenAccountsForSPLTokenAndToken2022() throws {
        XCTAssertEqual(
            try SolanaTransferTransactionBuilder.deriveAssociatedTokenAccountAddress(
                walletAddress: Self.destinationWallet,
                mintAddress: Self.mint
            ),
            Self.destinationWalletSPLAssociatedTokenAccount
        )
        XCTAssertEqual(
            try SolanaTransferTransactionBuilder.deriveAssociatedTokenAccountAddress(
                walletAddress: Self.destinationWallet,
                mintAddress: Self.mint,
                tokenProgram: .token2022
            ),
            Self.destinationWalletToken2022AssociatedTokenAccount
        )
    }

    func testRejectsMalformedTokenTransferParameters() {
        assertTransferError(.invalidTokenAmount) {
            _ = try SolanaTransferTransactionBuilder.buildTokenTransferChecked(
                ownerAddress: Self.owner,
                sourceTokenAccount: Self.sourceTokenAccount,
                destinationTokenAccount: Self.destinationTokenAccount,
                mintAddress: Self.mint,
                rawAmount: 0,
                decimals: 6,
                recentBlockhash: Self.blockhash
            )
        }
        assertTransferError(.invalidTokenDecimals) {
            _ = try SolanaTransferTransactionBuilder.buildTokenTransferChecked(
                ownerAddress: Self.owner,
                sourceTokenAccount: Self.sourceTokenAccount,
                destinationTokenAccount: Self.destinationTokenAccount,
                mintAddress: Self.mint,
                rawAmount: 1,
                decimals: 256,
                recentBlockhash: Self.blockhash
            )
        }
        assertTransferError(.duplicateAccount) {
            _ = try SolanaTransferTransactionBuilder.buildTokenTransferChecked(
                ownerAddress: Self.owner,
                sourceTokenAccount: Self.sourceTokenAccount,
                destinationTokenAccount: Self.sourceTokenAccount,
                mintAddress: Self.mint,
                rawAmount: 1,
                decimals: 6,
                recentBlockhash: Self.blockhash
            )
        }
        assertTransferError(.invalidWallet) {
            _ = try SolanaTransferTransactionBuilder.buildTokenSendChecked(
                ownerAddress: Self.owner,
                sourceTokenAccount: Self.sourceTokenAccount,
                destinationTokenAccount: Self.destinationTokenAccount,
                mintAddress: Self.mint,
                rawAmount: 1,
                decimals: 6,
                recentBlockhash: Self.blockhash,
                destinationWalletAddress: "not-base58"
            )
        }
        assertTransferError(.duplicateAccount) {
            _ = try SolanaTransferTransactionBuilder.buildTokenSendChecked(
                ownerAddress: Self.owner,
                sourceTokenAccount: Self.sourceTokenAccount,
                mintAddress: Self.mint,
                rawAmount: 1,
                decimals: 6,
                recentBlockhash: Self.blockhash,
                destinationWalletAddress: Self.sourceTokenAccount
            )
        }
        assertTransferError(.duplicateAccount) {
            _ = try SolanaTransferTransactionBuilder.buildTokenSendChecked(
                ownerAddress: Self.owner,
                sourceTokenAccount: Self.sourceTokenAccount,
                mintAddress: Self.mint,
                rawAmount: 1,
                decimals: 6,
                recentBlockhash: Self.blockhash,
                extraAccounts: [
                    SolanaTokenTransferExtraAccount(address: SolanaTransferTransactionBuilder.associatedTokenProgramAddress)
                ],
                destinationWalletAddress: Self.destinationWallet
            )
        }
        assertTransferError(.invalidAssociatedTokenAccount) {
            _ = try SolanaTransferTransactionBuilder.buildTokenSendChecked(
                ownerAddress: Self.owner,
                sourceTokenAccount: Self.sourceTokenAccount,
                destinationTokenAccount: Self.destinationTokenAccount,
                mintAddress: Self.mint,
                rawAmount: 1,
                decimals: 6,
                recentBlockhash: Self.blockhash,
                destinationWalletAddress: Self.destinationWallet
            )
        }
        assertTransferError(.invalidExtraAccount) {
            _ = try SolanaTransferTransactionBuilder.buildTokenTransferChecked(
                ownerAddress: Self.owner,
                sourceTokenAccount: Self.sourceTokenAccount,
                destinationTokenAccount: Self.destinationTokenAccount,
                mintAddress: Self.mint,
                rawAmount: 1,
                decimals: 6,
                recentBlockhash: Self.blockhash,
                extraAccounts: [SolanaTokenTransferExtraAccount(address: "not-base58")]
            )
        }
        assertTransferError(.tooManyExtraAccounts) {
            _ = try SolanaTransferTransactionBuilder.buildTokenTransferChecked(
                ownerAddress: Self.owner,
                sourceTokenAccount: Self.sourceTokenAccount,
                destinationTokenAccount: Self.destinationTokenAccount,
                mintAddress: Self.mint,
                rawAmount: 1,
                decimals: 6,
                recentBlockhash: Self.blockhash,
                extraAccounts: (10 ..< 43).map { try SolanaTokenTransferExtraAccount(address: Self.deriveAddress($0)) }
            )
        }
        assertTransferError(.invalidAssociatedTokenAccount) {
            _ = try SolanaTransferTransactionBuilder.buildCreateAssociatedTokenAccount(
                fundingAddress: Self.owner,
                walletAddress: Self.owner,
                associatedTokenAccount: "not-base58",
                mintAddress: Self.mint,
                recentBlockhash: Self.blockhash
            )
        }
        assertTransferError(.duplicateAccount) {
            _ = try SolanaTransferTransactionBuilder.buildCreateAssociatedTokenAccount(
                fundingAddress: Self.owner,
                walletAddress: Self.owner,
                mintAddress: Self.owner,
                recentBlockhash: Self.blockhash
            )
        }
        assertTransferError(.invalidAssociatedTokenAccount) {
            _ = try SolanaTransferTransactionBuilder.buildCreateAssociatedTokenAccount(
                fundingAddress: Self.owner,
                walletAddress: Self.owner,
                associatedTokenAccount: Self.owner,
                mintAddress: Self.mint,
                recentBlockhash: Self.blockhash
            )
        }
    }

    private func XCTAssertTransferInstruction(
        _ message: Data,
        lamports: Int64,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(message.count, 150, file: file, line: line)
        XCTAssertEqual(message.subdata(in: 0 ..< 3), Data([1, 0, 1]), file: file, line: line)
        XCTAssertEqual(message[3], 3, file: file, line: line)
        XCTAssertEqual(message[132], 1, file: file, line: line)
        XCTAssertEqual(message[133], 2, file: file, line: line)
        XCTAssertEqual(message[134], 2, file: file, line: line)
        XCTAssertEqual(message.subdata(in: 135 ..< 137), Data([0, 1]), file: file, line: line)
        XCTAssertEqual(message[137], 12, file: file, line: line)
        XCTAssertEqual(message.subdata(in: 138 ..< 142), Data([2, 0, 0, 0]), file: file, line: line)
        XCTAssertEqual(message.subdata(in: 142 ..< 150).littleEndianInt64(), lamports, file: file, line: line)
    }

    private func XCTAssertTokenTransferCheckedInstruction(
        _ message: Data,
        accountCount: Int,
        programIndex: Int,
        accountIndexes: [Int],
        amount: Int64,
        decimals: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        var offset = 0
        offset += 3
        XCTAssertEqual(Int(message[offset]), accountCount, file: file, line: line)
        offset += 1 + accountCount * 32
        offset += 32
        XCTAssertEqual(Int(message[offset]), 1, file: file, line: line)
        offset += 1
        XCTAssertEqual(Int(message[offset]), programIndex, file: file, line: line)
        offset += 1
        XCTAssertEqual(Int(message[offset]), accountIndexes.count, file: file, line: line)
        offset += 1
        XCTAssertEqual(message.subdata(in: offset ..< offset + accountIndexes.count), Data(accountIndexes.map(UInt8.init)), file: file, line: line)
        offset += accountIndexes.count
        XCTAssertEqual(Int(message[offset]), 10, file: file, line: line)
        offset += 1
        XCTAssertEqual(Int(message[offset]), 12, file: file, line: line)
        offset += 1
        XCTAssertEqual(message.subdata(in: offset ..< offset + 8).littleEndianInt64(), amount, file: file, line: line)
        offset += 8
        XCTAssertEqual(Int(message[offset]), decimals, file: file, line: line)
        offset += 1
        XCTAssertEqual(offset, message.count, file: file, line: line)
    }

    private func XCTAssertTokenSendWithAssociatedAccountCreateInstructions(
        _ message: Data,
        accountCount: Int,
        associatedProgramIndex: Int,
        associatedAccountIndexes: [Int],
        associatedDiscriminator: Int,
        tokenProgramIndex: Int,
        tokenAccountIndexes: [Int],
        amount: Int64,
        decimals: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        var offset = 0
        offset += 3
        XCTAssertEqual(Int(message[offset]), accountCount, file: file, line: line)
        offset += 1 + accountCount * 32
        offset += 32
        XCTAssertEqual(Int(message[offset]), 2, file: file, line: line)
        offset += 1

        XCTAssertEqual(Int(message[offset]), associatedProgramIndex, file: file, line: line)
        offset += 1
        XCTAssertEqual(Int(message[offset]), associatedAccountIndexes.count, file: file, line: line)
        offset += 1
        XCTAssertEqual(
            message.subdata(in: offset ..< offset + associatedAccountIndexes.count),
            Data(associatedAccountIndexes.map(UInt8.init)),
            file: file,
            line: line
        )
        offset += associatedAccountIndexes.count
        XCTAssertEqual(Int(message[offset]), 1, file: file, line: line)
        offset += 1
        XCTAssertEqual(Int(message[offset]), associatedDiscriminator, file: file, line: line)
        offset += 1

        XCTAssertEqual(Int(message[offset]), tokenProgramIndex, file: file, line: line)
        offset += 1
        XCTAssertEqual(Int(message[offset]), tokenAccountIndexes.count, file: file, line: line)
        offset += 1
        XCTAssertEqual(
            message.subdata(in: offset ..< offset + tokenAccountIndexes.count),
            Data(tokenAccountIndexes.map(UInt8.init)),
            file: file,
            line: line
        )
        offset += tokenAccountIndexes.count
        XCTAssertEqual(Int(message[offset]), 10, file: file, line: line)
        offset += 1
        XCTAssertEqual(Int(message[offset]), 12, file: file, line: line)
        offset += 1
        XCTAssertEqual(message.subdata(in: offset ..< offset + 8).littleEndianInt64(), amount, file: file, line: line)
        offset += 8
        XCTAssertEqual(Int(message[offset]), decimals, file: file, line: line)
        offset += 1
        XCTAssertEqual(offset, message.count, file: file, line: line)
    }

    private func XCTAssertAssociatedTokenCreateInstruction(
        _ message: Data,
        accountCount: Int,
        programIndex: Int,
        accountIndexes: [Int],
        discriminator: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        var offset = 0
        offset += 3
        XCTAssertEqual(Int(message[offset]), accountCount, file: file, line: line)
        offset += 1 + accountCount * 32
        offset += 32
        XCTAssertEqual(Int(message[offset]), 1, file: file, line: line)
        offset += 1
        XCTAssertEqual(Int(message[offset]), programIndex, file: file, line: line)
        offset += 1
        XCTAssertEqual(Int(message[offset]), accountIndexes.count, file: file, line: line)
        offset += 1
        XCTAssertEqual(message.subdata(in: offset ..< offset + accountIndexes.count), Data(accountIndexes.map(UInt8.init)), file: file, line: line)
        offset += accountIndexes.count
        XCTAssertEqual(Int(message[offset]), 1, file: file, line: line)
        offset += 1
        XCTAssertEqual(Int(message[offset]), discriminator, file: file, line: line)
        offset += 1
        XCTAssertEqual(offset, message.count, file: file, line: line)
    }

    private func assertTransferError(
        _ expected: SolanaTransferTransactionError,
        file: StaticString = #filePath,
        line: UInt = #line,
        block: () throws -> Void
    ) {
        XCTAssertThrowsError(try block(), file: file, line: line) { error in
            XCTAssertEqual(error as? SolanaTransferTransactionError, expected, file: file, line: line)
        }
    }

    private static let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
    private static let sender = try! SolanaKeyDerivation.deriveAccount(mnemonic: mnemonic).address
    private static let owner = try! deriveAddress(6)
    private static let sourceTokenAccount = try! deriveAddress(1)
    private static let destinationTokenAccount = try! deriveAddress(2)
    private static let mint = try! deriveAddress(3)
    private static let extraReadonlyAccount = try! deriveAddress(4)
    private static let extraWritableAccount = try! deriveAddress(5)
    private static let destinationWallet = try! deriveAddress(7)
    private static let ownerSPLAssociatedTokenAccount = "J6SUEJJ82hffdpF15LHppEoRn3e7rzu4sf4dS1WWzBpA"
    private static let ownerToken2022AssociatedTokenAccount = "Cozse4NYMaBEXmydu6nYwYsFD29LXwU7K6n1AiEeDkHw"
    private static let destinationWalletSPLAssociatedTokenAccount = "BNrmzq2GNxwxHf8dSiaEJdtUiQBg4VGCFi9ovhAK6WrK"
    private static let destinationWalletToken2022AssociatedTokenAccount = "2bFPe5wRzpinUSyFT42imC5DFHtEFugZ6UhgBeWRRxhH"
    private static let recipient = "So11111111111111111111111111111111111111112"
    private static let blockhash = "7GjNiPun3AzEazTZoFEjZgcBMeuaXdpjHq2raZTmTrfs"

    private static func deriveAddress(_ index: Int) throws -> String {
        try SolanaKeyDerivation
            .deriveAccount(mnemonic: mnemonic, derivationPath: "m/44'/501'/\(index)'/0'")
            .address
    }
}

private extension Data {
    func littleEndianInt64() -> Int64 {
        var value: UInt64 = 0
        for (index, byte) in enumerated() {
            value |= UInt64(byte) << UInt64(index * 8)
        }

        return Int64(bitPattern: value)
    }
}
