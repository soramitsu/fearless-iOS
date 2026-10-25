import XCTest
@testable import fearless
import CoreData
import IrohaCrypto
import RobinHood
import SoraKeystore
import SSFModels

/// IK-11: stored per-chain account rows are judged one by one. One bad row never hides or
/// rejects its wallet, and a row that the 4.0.x releases hid never takes over from the
/// address those releases showed.
final class StoredChainAccountRecordsTests: XCTestCase {
    private let polkadot = ChainAccountRecordsFixture.chain(id: ChainAccountRecordsFixture.polkadotChainId)
    private let kusama = ChainAccountRecordsFixture.chain(id: ChainAccountRecordsFixture.kusamaChainId, prefix: 2)
    private let moonbeam = ChainAccountRecordsFixture.chain(
        id: ChainAccountRecordsFixture.moonbeamChainId, ethereumBased: true
    )

    func testInvalidChainRow_whenStored_thenWalletStaysUsableAndOnlyThatRowIsReported() throws {
        let facade = UserDataStorageTestFacade()
        let wallet = AccountGenerator.generateMetaAccount(generatingChainAccounts: 0)
        let valid = ChainAccountRecordsFixture.substrateAccount(chainId: kusama.chainId, marker: 0x21)
        try ChainAccountRecordsFixture.save(wallet.replacingChainAccounts([valid]), in: facade)
        try ChainAccountRecordsFixture.insertRow(in: wallet.metaId, facade: facade) { row in
            row.setValue(self.polkadot.chainId, forKey: "chainId")
            row.setValue(Data(repeating: 0x31, count: 32).toHex(), forKey: "accountId")
            row.setValue(Data(repeating: 0x32, count: 31), forKey: "publicKey")
            row.setValue(Int16(CryptoType.sr25519.rawValue), forKey: "cryptoType")
            row.setValue(false, forKey: "ethereumBased")
        }
        let rowsBefore = try ChainAccountRecordsFixture.rawRows(of: wallet.metaId, in: facade)

        let projection = try XCTUnwrap(
            try ChainAccountRecordsFixture.projections(in: facade).first { $0.identifier == wallet.metaId }
        )

        XCTAssertEqual(projection.recordState, .supported)
        let mapped = try XCTUnwrap(projection.wallet)
        XCTAssertEqual(mapped.chainAccounts, [valid])
        XCTAssertEqual(
            projection.chainAccountRecords?.unusable,
            [UnusableStoredChainAccount(chainId: polkadot.chainId, issue: .invalidPublicKey)]
        )
        // The skipped row's network falls back to the wallet's own account.
        XCTAssertEqual(mapped.fetch(for: polkadot.accountRequest())?.accountId, wallet.substrateAccountId)
        XCTAssertEqual(mapped.fetch(for: kusama.accountRequest())?.accountId, valid.accountId)

        // Saving the wallet works and leaves the invalid row exactly as it was.
        try ChainAccountRecordsFixture.save(mapped.replacingName("Renamed"), in: facade)
        XCTAssertEqual(try ChainAccountRecordsFixture.rawRows(of: wallet.metaId, in: facade), rowsBefore)
        XCTAssertEqual(try ChainAccountRecordsFixture.wallets(in: facade).first?.name, "Renamed")
    }

    func testEveryInvalidRowKind_whenStored_thenOnlyThatRowIsSkippedWithItsIssue() throws {
        let cases: [(String, StoredChainAccountIssue, (NSManagedObject) -> Void)] = [
            ("empty-chain", .invalidChainId, { $0.setValue("", forKey: "chainId") }),
            ("padded-chain", .invalidChainId, { $0.setValue(" padded-chain ", forKey: "chainId") }),
            ("crypto", .invalidCryptoType, { $0.setValue(Int16.max, forKey: "cryptoType") }),
            ("not-hex", .invalidAccountId, { $0.setValue("not-hex", forKey: "accountId") }),
            ("empty-account", .invalidAccountId, { $0.setValue("", forKey: "accountId") }),
            ("short-key", .invalidPublicKey, { $0.setValue(Data(repeating: 1, count: 31), forKey: "publicKey") }),
            ("ecdsa-key", .invalidPublicKey, {
                $0.setValue(Int16(CryptoType.ecdsa.rawValue), forKey: "cryptoType")
            })
        ]

        for (name, issue, corrupt) in cases {
            let facade = UserDataStorageTestFacade()
            let wallet = AccountGenerator.generateMetaAccount(generatingChainAccounts: 0)
            try ChainAccountRecordsFixture.save(wallet, in: facade)
            try ChainAccountRecordsFixture.insertRow(in: wallet.metaId, facade: facade) { row in
                row.setValue("chain-\(name)", forKey: "chainId")
                row.setValue(Data(repeating: 0x41, count: 32).toHex(), forKey: "accountId")
                row.setValue(Data(repeating: 0x42, count: 32), forKey: "publicKey")
                row.setValue(Int16(CryptoType.sr25519.rawValue), forKey: "cryptoType")
                row.setValue(false, forKey: "ethereumBased")
                corrupt(row)
            }

            let projection = try XCTUnwrap(try ChainAccountRecordsFixture.projections(in: facade).first, name)
            XCTAssertEqual(projection.recordState, .supported, name)
            XCTAssertEqual(projection.wallet?.chainAccounts, [], name)
            XCTAssertEqual(projection.chainAccountRecords?.unusable.map(\.issue), [issue], name)
        }
    }

    func testRowThatCannotMaterialize_whenRead_thenOnlyThatRowIsSkippedAndTheWalletMaps() throws {
        let context = try ChainAccountRecordsFixture.makeContextWithUnreadableChainAccountRows()
        let wallet = AccountGenerator.generateMetaAccount(generatingChainAccounts: 0)
        var result: Result<(MetaAccountModel, StoredChainAccountRecords, MetaAccountSelectionModel), Error>?

        context.performAndWait {
            result = Result {
                let entities = try XCTUnwrap(context.persistentStoreCoordinator?.managedObjectModel.entitiesByName)
                let entity = CDMetaAccount(entity: try XCTUnwrap(entities["CDMetaAccount"]), insertInto: context)
                try MetaAccountMapper().populate(entity: entity, from: wallet, using: context)
                entity.isSelected = true
                let row = UnreadableChainAccountRow(entity: try XCTUnwrap(entities["CDChainAccount"]), insertInto: context)
                entity.mutableSetValue(forKey: "chainAccounts").add(row)

                let mapped = try MetaAccountMapper().transformWithChainAccountRecords(entity: entity)
                let projection = try MetaAccountSelectionMapper().transform(entity: entity)
                return (mapped.wallet, mapped.chainAccountRecords, projection)
            }
        }

        let (mapped, records, projection) = try XCTUnwrap(result).get()
        XCTAssertEqual(mapped.metaId, wallet.metaId)
        XCTAssertEqual(mapped.chainAccounts, [])
        XCTAssertEqual(records.unusable, [UnusableStoredChainAccount(chainId: nil, issue: .unreadable)])
        XCTAssertEqual(projection.recordState, .supported)
    }

    func testRowHiddenBy40x_whenWalletHasItsOwnAccount_thenWalletAccountStaysInUseAndRowIsAnAlternative() throws {
        let facade = UserDataStorageTestFacade()
        let wallet = AccountGenerator.generateMetaAccount(generatingChainAccounts: 0)
        let hidden = ChainAccountRecordsFixture.substrateAccount(chainId: polkadot.chainId, marker: 0x51)
        try ChainAccountRecordsFixture.save(wallet, in: facade)
        try ChainAccountRecordsFixture.insertHiddenRow(hidden, in: wallet.metaId, facade: facade)

        let projection = try XCTUnwrap(try ChainAccountRecordsFixture.projections(in: facade).first)
        let mapped = try XCTUnwrap(projection.wallet)

        XCTAssertEqual(mapped.chainAccounts, [])
        XCTAssertEqual(mapped.fetch(for: polkadot.accountRequest())?.accountId, wallet.substrateAccountId)
        XCTAssertEqual(mapped.fetch(for: polkadot.accountRequest())?.isChainAccount, false)
        XCTAssertEqual(projection.chainAccountRecords?.alternatives, [hidden])
        XCTAssertEqual(projection.chainAccountRecords?.unusable, [])
    }

    func testRowHiddenBy40x_whenWalletHasNoAccountOfThatKind_thenRowStaysInUse() throws {
        let facade = UserDataStorageTestFacade()
        // Wallets created before Ethereum support have no Ethereum account of their own.
        let wallet = AccountGenerator.generateMetaAccount(generatingChainAccounts: 0)
            .replacingEthereumAddress(nil)
            .replacingEthereumPublicKey(nil)
        let hidden = ChainAccountRecordsFixture.ethereumAccount(chainId: moonbeam.chainId, marker: 0x61)
        try ChainAccountRecordsFixture.save(wallet, in: facade)
        try ChainAccountRecordsFixture.insertHiddenRow(hidden, in: wallet.metaId, facade: facade)

        let projection = try XCTUnwrap(try ChainAccountRecordsFixture.projections(in: facade).first)
        let mapped = try XCTUnwrap(projection.wallet)

        XCTAssertEqual(mapped.chainAccounts, [hidden])
        XCTAssertEqual(mapped.fetch(for: moonbeam.accountRequest())?.accountId, hidden.accountId)
        XCTAssertEqual(projection.chainAccountRecords?.alternatives, [])
    }

    func testHiddenEthereumRow_whenSelected_thenStoredAsEthereumNeverSubstrate() throws {
        let facade = UserDataStorageTestFacade()
        let wallet = AccountGenerator.generateMetaAccount(generatingChainAccounts: 0)
        let hidden = ChainAccountRecordsFixture.ethereumAccount(chainId: moonbeam.chainId, marker: 0x71)
        try ChainAccountRecordsFixture.save(wallet, in: facade)
        try ChainAccountRecordsFixture.insertHiddenRow(hidden, in: wallet.metaId, facade: facade)

        let alternative = try XCTUnwrap(
            try ChainAccountRecordsFixture.projections(in: facade).first?.chainAccountRecords?.alternatives.first
        )
        // The row carries neither label; its 20-byte ECDSA account still reads as Ethereum.
        XCTAssertTrue(alternative.ethereumBased)

        try ChainAccountRecordsFixture.select(
            .chainAccount(accountId: hidden.accountId, publicKey: hidden.publicKey),
            chainId: moonbeam.chainId, walletId: wallet.metaId, facade: facade
        )

        let rows = try ChainAccountRecordsFixture.rawRows(of: wallet.metaId, in: facade)
        XCTAssertEqual(rows.map(\.ecosystem), [UniversalWalletEcosystem.evm.rawValue])
        XCTAssertEqual(rows.map(\.ethereumBased), [true])
        let mapped = try XCTUnwrap(try ChainAccountRecordsFixture.wallets(in: facade).first)
        XCTAssertEqual(mapped.fetch(for: moonbeam.accountRequest())?.accountId, hidden.accountId)
    }

    func testRowLabelledSubstrateByEarlier42Build_whenSaved_thenLabelIsCorrectedToEthereum() throws {
        let facade = UserDataStorageTestFacade()
        let wallet = AccountGenerator.generateMetaAccount(generatingChainAccounts: 0)
        let account = ChainAccountRecordsFixture.ethereumAccount(chainId: moonbeam.chainId, marker: 0x81)
        try ChainAccountRecordsFixture.save(wallet, in: facade)
        // TestFlight 4.2 builds resurfaced 4.0.x rows and labelled each one as Substrate.
        try ChainAccountRecordsFixture.insertRow(in: wallet.metaId, facade: facade) { row in
            ChainAccountRecordsFixture.write(account, to: row)
            row.setValue(false, forKey: "ethereumBased")
            row.setValue(UniversalWalletEcosystem.substrate.rawValue, forKey: "ecosystem")
        }

        let mapped = try XCTUnwrap(try ChainAccountRecordsFixture.wallets(in: facade).first)
        XCTAssertEqual(mapped.chainAccounts, [account])
        XCTAssertEqual(mapped.fetch(for: moonbeam.accountRequest())?.accountId, account.accountId)

        try ChainAccountRecordsFixture.save(mapped, in: facade)

        let rows = try ChainAccountRecordsFixture.rawRows(of: wallet.metaId, in: facade)
        XCTAssertEqual(rows.map(\.ecosystem), [UniversalWalletEcosystem.evm.rawValue])
        XCTAssertEqual(rows.map(\.ethereumBased), [true])
        XCTAssertEqual(rows.map(\.accountId), [account.accountId.toHex()])
    }

    func testOrdinarySave_whenModelStillCarriesAnAlternative_thenItStaysUnusedAndUnchanged() throws {
        let facade = UserDataStorageTestFacade()
        let wallet = AccountGenerator.generateMetaAccount(generatingChainAccounts: 0)
        let hidden = ChainAccountRecordsFixture.substrateAccount(chainId: polkadot.chainId, marker: 0x91)
        try ChainAccountRecordsFixture.save(wallet, in: facade)
        try ChainAccountRecordsFixture.insertHiddenRow(hidden, in: wallet.metaId, facade: facade)
        let rowsBefore = try ChainAccountRecordsFixture.rawRows(of: wallet.metaId, in: facade)

        // A copy of the wallet that still lists the account, as one held from before a switch.
        try ChainAccountRecordsFixture.save(wallet.replacingChainAccounts([hidden]), in: facade)

        XCTAssertEqual(try ChainAccountRecordsFixture.rawRows(of: wallet.metaId, in: facade), rowsBefore)
        let mapped = try XCTUnwrap(try ChainAccountRecordsFixture.wallets(in: facade).first)
        XCTAssertEqual(mapped.fetch(for: polkadot.accountRequest())?.accountId, wallet.substrateAccountId)
    }

    func testExplicitSelection_whenSwitchingBackAndForth_thenOnlyTheInUseMarkingChanges() throws {
        let facade = UserDataStorageTestFacade()
        let wallet = AccountGenerator.generateMetaAccount(generatingChainAccounts: 0)
        let hidden = ChainAccountRecordsFixture.substrateAccount(chainId: polkadot.chainId, marker: 0xA1)
        let other = ChainAccountRecordsFixture.substrateAccount(chainId: kusama.chainId, marker: 0xA2)
        try ChainAccountRecordsFixture.save(wallet.replacingChainAccounts([other]), in: facade)
        try ChainAccountRecordsFixture.insertHiddenRow(hidden, in: wallet.metaId, facade: facade)

        try ChainAccountRecordsFixture.select(
            .chainAccount(accountId: hidden.accountId, publicKey: hidden.publicKey),
            chainId: polkadot.chainId, walletId: wallet.metaId, facade: facade
        )
        var mapped = try XCTUnwrap(try ChainAccountRecordsFixture.wallets(in: facade).first)
        XCTAssertEqual(mapped.fetch(for: polkadot.accountRequest())?.accountId, hidden.accountId)
        XCTAssertEqual(mapped.fetch(for: kusama.accountRequest())?.accountId, other.accountId)

        try ChainAccountRecordsFixture.select(
            .walletAccount, chainId: polkadot.chainId, walletId: wallet.metaId, facade: facade
        )
        mapped = try XCTUnwrap(try ChainAccountRecordsFixture.wallets(in: facade).first)
        XCTAssertEqual(mapped.fetch(for: polkadot.accountRequest())?.accountId, wallet.substrateAccountId)
        XCTAssertEqual(mapped.fetch(for: kusama.accountRequest())?.accountId, other.accountId)

        // Both rows are still stored with the same accounts, keys and networks.
        let rows = try ChainAccountRecordsFixture.rawRows(of: wallet.metaId, in: facade)
        XCTAssertEqual(
            Set(rows.map { "\($0.chainId ?? "")|\($0.accountId ?? "")|\($0.publicKey?.toHex() ?? "")" }),
            Set([hidden, other].map { "\($0.chainId)|\($0.accountId.toHex())|\($0.publicKey.toHex())" })
        )
        XCTAssertEqual(
            try ChainAccountRecordsFixture.projections(in: facade).first?.chainAccountRecords?.alternatives,
            [hidden]
        )
    }

    /// A per-network account replaced by another one created or imported for the same network
    /// (Wallet details, or a per-network account from a new phrase) used to be overwritten in
    /// its row, leaving its keys with no index. It now stays stored as an alternative: listed,
    /// selectable and exportable.
    func testNewAccountForANetworkInUse_whenSaved_thenThePreviousOneStaysStoredSelectableAndExportable() throws {
        let facade = UserDataStorageTestFacade()
        let keystore = InMemoryKeychain()
        let factory = MetaAccountOperationFactory(keystore: keystore)
        let firstPhrase = "legal winner thank year wave sausage worth useful legal winner thank yellow"
        let secondPhrase = "letter advice cage absurd amount doctor acoustic avoid letter advice cage above"
        let wallet = try run(factory.newMetaAccountOperation(
            request: MetaAccountImportMnemonicRequest(
                mnemonic: try IRMnemonicCreator().mnemonic(fromList: "bottom drive obey lake curtain smoke basket hold race lonely fit walk"),
                username: "Wallet", substrateDerivationPath: "",
                ethereumDerivationPath: DerivationPathConstants.defaultEthereum, cryptoType: .sr25519, defaultChainId: nil
            ),
            isBackuped: false
        ))
        try ChainAccountRecordsFixture.save(wallet, in: facade)
        let importKusama = { (phrase: String, into: MetaAccountModel) in
            try self.run(factory.importChainAccountOperation(request: ChainAccountImportMnemonicRequest(
                mnemonic: try IRMnemonicCreator().mnemonic(fromList: phrase), username: into.name,
                derivationPath: "", cryptoType: .sr25519, isEthereum: false, meta: into, chainId: self.kusama.chainId
            )))
        }

        let withFirst = try importKusama(firstPhrase, try XCTUnwrap(try ChainAccountRecordsFixture.wallets(in: facade).first))
        try ChainAccountRecordsFixture.save(withFirst, in: facade)
        let first = try XCTUnwrap(withFirst.chainAccounts.first { $0.chainId == kusama.chainId })
        let withSecond = try importKusama(secondPhrase, try XCTUnwrap(try ChainAccountRecordsFixture.wallets(in: facade).first))
        XCTAssertFalse(withSecond.chainAccounts.contains(first), "the model drops the replaced account")
        try ChainAccountRecordsFixture.save(withSecond, in: facade)
        let second = try XCTUnwrap(withSecond.chainAccounts.first { $0.chainId == kusama.chainId })
        XCTAssertNotEqual(first.accountId, second.accountId)

        var mapped = try XCTUnwrap(try ChainAccountRecordsFixture.wallets(in: facade).first)
        XCTAssertEqual(mapped.fetch(for: kusama.accountRequest())?.accountId, second.accountId, "the new account is in use")
        XCTAssertEqual(try ChainAccountRecordsFixture.projections(in: facade).first?.chainAccountRecords?.alternatives, [first])
        let rows = try ChainAccountRecordsFixture.rawRows(of: wallet.metaId, in: facade).filter { $0.chainId == kusama.chainId }
        XCTAssertEqual(Set(rows.compactMap(\.accountId)), Set([first, second].map { $0.accountId.toHex() }))

        // The replaced account can be switched back to, and its own phrase and seed are still read.
        try ChainAccountRecordsFixture.select(
            .chainAccount(accountId: first.accountId, publicKey: first.publicKey),
            chainId: kusama.chainId, walletId: wallet.metaId, facade: facade
        )
        mapped = try XCTUnwrap(try ChainAccountRecordsFixture.wallets(in: facade).first)
        XCTAssertEqual(mapped.fetch(for: kusama.accountRequest())?.accountId, first.accountId)
        XCTAssertEqual(
            try keystore.fetchKey(for: fearless.KeystoreTagV2.entropyTagForMetaId(wallet.metaId, accountId: first.accountId)),
            try IRMnemonicCreator().mnemonic(fromList: firstPhrase).entropy()
        )
        XCTAssertNoThrow(try VerifiedSeedExportReader(keystore: keystore).fetchSeed(
            metaId: wallet.metaId, accountId: first.accountId, publicKey: first.publicKey,
            cryptoType: .sr25519, ethereumBased: false
        ))
    }

    /// Codex #3: Wallet options keeps the wallet from when it opened. Switching a network to a
    /// stored per-chain account in Details and then renaming from the older copy must not
    /// publish the address the user switched away from.
    func testStaleWalletCopy_whenSavedAfterAnExplicitSwitch_thenTheSaveReturnsTheSwitchedAccount() throws {
        let facade = UserDataStorageTestFacade()
        let wallet = AccountGenerator.generateMetaAccount(generatingChainAccounts: 0)
        let hidden = ChainAccountRecordsFixture.substrateAccount(chainId: polkadot.chainId, marker: 0xB1)
        try ChainAccountRecordsFixture.save(wallet, in: facade)
        try ChainAccountRecordsFixture.insertHiddenRow(hidden, in: wallet.metaId, facade: facade)
        let staleCopy = try XCTUnwrap(try ChainAccountRecordsFixture.wallets(in: facade).first)
        XCTAssertEqual(staleCopy.fetch(for: polkadot.accountRequest())?.accountId, wallet.substrateAccountId)

        try ChainAccountRecordsFixture.select(
            .chainAccount(accountId: hidden.accountId, publicKey: hidden.publicKey),
            chainId: polkadot.chainId, walletId: wallet.metaId, facade: facade
        )
        let settings = SelectedWalletSettings(storageFacade: facade, operationQueue: OperationQueue())
        let saved = expectation(description: "rename saved")
        var result: Result<MetaAccountModel, Error>?
        settings.performSave(value: staleCopy.replacingName("Renamed")) {
            result = $0
            saved.fulfill()
        }
        wait(for: [saved], timeout: 10)

        let returned = try XCTUnwrap(result).get()
        XCTAssertEqual(returned.name, "Renamed")
        XCTAssertEqual(returned.fetch(for: polkadot.accountRequest())?.accountId, hidden.accountId)
        let stored = try XCTUnwrap(try ChainAccountRecordsFixture.wallets(in: facade).first)
        XCTAssertEqual(stored.fetch(for: polkadot.accountRequest())?.accountId, hidden.accountId)
        XCTAssertEqual(returned.chainAccounts, stored.chainAccounts, "the app holds what the store holds")
    }

    func testExplicitSelection_whenAccountIsNotStored_thenFailsWithoutChanges() throws {
        let facade = UserDataStorageTestFacade()
        let wallet = AccountGenerator.generateMetaAccount(generatingChainAccounts: 0)
        let hidden = ChainAccountRecordsFixture.substrateAccount(chainId: polkadot.chainId, marker: 0xA5)
        try ChainAccountRecordsFixture.save(wallet, in: facade)
        try ChainAccountRecordsFixture.insertHiddenRow(hidden, in: wallet.metaId, facade: facade)
        let rowsBefore = try ChainAccountRecordsFixture.rawRows(of: wallet.metaId, in: facade)

        XCTAssertThrowsError(
            try ChainAccountRecordsFixture.select(
                .chainAccount(accountId: Data(repeating: 0xEE, count: 32), publicKey: Data(repeating: 0xEF, count: 32)),
                chainId: polkadot.chainId, walletId: wallet.metaId, facade: facade
            )
        ) { error in
            XCTAssertEqual(error as? ChainAccountSelectionError, .accountNotStored)
        }
        XCTAssertThrowsError(
            try ChainAccountRecordsFixture.select(
                .walletAccount, chainId: UniversalWalletRegistry.bitcoinMainnet.chainId,
                walletId: wallet.metaId, facade: facade
            )
        ) { error in
            XCTAssertEqual(error as? ChainAccountSelectionError, .unsupportedChain)
        }
        XCTAssertEqual(try ChainAccountRecordsFixture.rawRows(of: wallet.metaId, in: facade), rowsBefore)
    }

    func testDuplicateRows_whenStoredForOneNetwork_thenOneIsUsedDeterministicallyAndOtherIsAnAlternative() throws {
        let facade = UserDataStorageTestFacade()
        let wallet = AccountGenerator.generateMetaAccount(generatingChainAccounts: 0)
        let lower = ChainAccountRecordsFixture.substrateAccount(chainId: polkadot.chainId, marker: 0x11)
        let higher = ChainAccountRecordsFixture.substrateAccount(chainId: polkadot.chainId, marker: 0x12)
        try ChainAccountRecordsFixture.save(wallet, in: facade)
        // Release 2.0.0 matched rows by network and account, so one network could get two rows.
        for account in [higher, lower] {
            try ChainAccountRecordsFixture.insertRow(in: wallet.metaId, facade: facade) { row in
                ChainAccountRecordsFixture.write(account, to: row)
                row.setValue(false, forKey: "ethereumBased")
            }
        }

        let projection = try XCTUnwrap(try ChainAccountRecordsFixture.projections(in: facade).first)
        XCTAssertEqual(projection.recordState, .supported)
        XCTAssertEqual(projection.wallet?.chainAccounts, [lower])
        XCTAssertEqual(projection.chainAccountRecords?.alternatives, [higher])
    }

    func testDuplicateDerivedNetworkRows_whenStored_thenOneIsUsedAndTheOtherIsReportedNotOffered() throws {
        let facade = UserDataStorageTestFacade()
        let wallet = AccountGenerator.generateMetaAccount(generatingChainAccounts: 0)
        let bitcoin = UniversalWalletRegistry.bitcoinMainnet
        try ChainAccountRecordsFixture.save(wallet, in: facade)
        for (chainId, marker) in [(bitcoin.chainId, UInt8(0x13)), (bitcoin.id, UInt8(0x14))] {
            try ChainAccountRecordsFixture.insertRow(in: wallet.metaId, facade: facade) { row in
                ChainAccountRecordsFixture.write(
                    ChainAccountRecordsFixture.substrateAccount(chainId: chainId, marker: marker), to: row
                )
                row.setValue(false, forKey: "ethereumBased")
                row.setValue(UniversalWalletEcosystem.substrate.rawValue, forKey: "ecosystem")
            }
        }

        let projection = try XCTUnwrap(try ChainAccountRecordsFixture.projections(in: facade).first)
        XCTAssertEqual(projection.recordState, .supported)
        XCTAssertEqual(projection.wallet?.chainAccounts.count, 1)
        XCTAssertEqual(projection.wallet?.chainAccounts.first?.accountId, Data(repeating: 0x13, count: 32))
        XCTAssertEqual(projection.chainAccountRecords?.alternatives, [])
        XCTAssertEqual(projection.chainAccountRecords?.unusable.map(\.issue), [.duplicateDerivedAccount])
    }

    func testExactReplacement_whenNetworkIsDropped_thenAlternativesAndUnusableRowsStay() throws {
        let facade = UserDataStorageTestFacade()
        let wallet = AccountGenerator.generateMetaAccount(generatingChainAccounts: 0)
        let inUse = ChainAccountRecordsFixture.substrateAccount(chainId: kusama.chainId, marker: 0xB1)
        let hidden = ChainAccountRecordsFixture.substrateAccount(chainId: polkadot.chainId, marker: 0xB2)
        try ChainAccountRecordsFixture.save(wallet.replacingChainAccounts([inUse]), in: facade)
        try ChainAccountRecordsFixture.insertHiddenRow(hidden, in: wallet.metaId, facade: facade)
        try ChainAccountRecordsFixture.insertRow(in: wallet.metaId, facade: facade) { row in
            ChainAccountRecordsFixture.write(
                ChainAccountRecordsFixture.substrateAccount(chainId: "broken-chain", marker: 0xB3), to: row
            )
            row.setValue("not-hex", forKey: "accountId")
        }

        try ChainAccountRecordsFixture.save(wallet, in: facade, replacingChildrenExactly: true)

        let projection = try XCTUnwrap(try ChainAccountRecordsFixture.projections(in: facade).first)
        XCTAssertEqual(projection.wallet?.chainAccounts, [])
        XCTAssertEqual(projection.chainAccountRecords?.alternatives, [hidden])
        XCTAssertEqual(projection.chainAccountRecords?.unusable.map(\.chainId), ["broken-chain"])
    }
}

private extension StoredChainAccountRecordsTests {
    func run(_ operation: BaseOperation<MetaAccountModel>) throws -> MetaAccountModel {
        OperationQueue().addOperations([operation], waitUntilFinished: true)
        let result = try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        (operation as? PersistenceBoundKeychainOperation)?.commitKeychainChanges()
        return result
    }
}

/// Builds and inspects stored wallets for the IK-11 tests.
enum ChainAccountRecordsFixture {
    static let polkadotChainId = "91b171bb158e2d3848fa23a9f1c25182fb8e20313b2c1eb49219da7a70ce90c3"
    static let kusamaChainId = "b0a8d493285c2df73290dfb7e61f870f17b41801197a149ca93654499ea3dafe"
    static let moonbeamChainId = "fe58ea77779b7abda7da4ec526d14db9b1e9cd40a217c34892af80a9b332b76d"

    struct RawRow: Equatable {
        let chainId: String?
        let accountId: String?
        let publicKey: Data?
        let cryptoType: Int16
        let ethereumBased: Bool?
        let ecosystem: String?
    }

    static func chain(id: String, prefix: UInt16 = 0, ethereumBased: Bool = false) -> ChainModel {
        ChainModel(
            rank: nil,
            disabled: false,
            chainId: id,
            parentId: nil,
            paraId: nil,
            name: "Chain \(id.prefix(6))",
            xcm: nil,
            nodes: [],
            addressPrefix: prefix,
            types: nil,
            icon: nil,
            options: ethereumBased ? [.ethereumBased] : nil,
            externalApi: nil,
            selectedNode: nil,
            customNodes: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }

    static func substrateAccount(chainId: String, marker: UInt8) -> ChainAccountModel {
        ChainAccountModel(
            chainId: chainId,
            accountId: Data(repeating: marker, count: 32),
            publicKey: Data(repeating: marker &+ 1, count: 32),
            cryptoType: CryptoType.sr25519.rawValue,
            ethereumBased: false
        )
    }

    static func ethereumAccount(chainId: String, marker: UInt8) -> ChainAccountModel {
        ChainAccountModel(
            chainId: chainId,
            accountId: Data(repeating: marker, count: 20),
            publicKey: Data(repeating: marker &+ 1, count: 33),
            cryptoType: CryptoType.ecdsa.rawValue,
            ethereumBased: true
        )
    }

    static func write(_ account: ChainAccountModel, to row: NSManagedObject) {
        row.setValue(account.chainId, forKey: "chainId")
        row.setValue(account.accountId.toHex(), forKey: "accountId")
        row.setValue(account.publicKey, forKey: "publicKey")
        row.setValue(Int16(account.cryptoType), forKey: "cryptoType")
    }

    static func save(
        _ wallet: MetaAccountModel,
        in facade: UserDataStorageTestFacade,
        replacingChildrenExactly: Bool = false
    ) throws {
        let repository = facade.createRepository(mapper: AnyCoreDataMapper(MetaAccountSelectionMapper()))
        let save = repository.saveOperation({ [MetaAccountSelectionModel(
            identifier: wallet.metaId, wallet: wallet, isSelected: true,
            order: fearless.ManagedMetaAccountModel.noOrder, updatesWalletPayload: true,
            replacesWalletChildrenExactly: replacingChildrenExactly
        )] }, { [] })
        OperationQueue().addOperations([save], waitUntilFinished: true)
        _ = try XCTUnwrap(save.result).get()
    }

    static func select(
        _ selection: ChainAccountSelection,
        chainId: String,
        walletId: String,
        facade: UserDataStorageTestFacade
    ) throws {
        let operation = StoredWalletRecordsInspector(storageFacade: facade).selectChainAccountOperation(
            ChainAccountSelectionUpdate(chainId: chainId, selection: selection), walletId: walletId
        )
        OperationQueue().addOperations([operation], waitUntilFinished: true)
        _ = try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
    }

    static func projections(in facade: UserDataStorageTestFacade) throws -> [MetaAccountSelectionModel] {
        let repository = facade.createRepository(mapper: AnyCoreDataMapper(MetaAccountSelectionMapper()))
        let fetch = repository.fetchAllOperation(with: RepositoryFetchOptions(
            includesProperties: true, includesSubentities: true
        ))
        OperationQueue().addOperations([fetch], waitUntilFinished: true)
        return try XCTUnwrap(fetch.result).get()
    }

    static func wallets(in facade: UserDataStorageTestFacade) throws -> [MetaAccountModel] {
        try projections(in: facade).compactMap(\.wallet)
    }

    /// Adds a row in the shape the 4.0.x releases left behind: no `ecosystem`, no `ethereumBased`.
    static func insertHiddenRow(
        _ account: ChainAccountModel,
        in walletId: String,
        facade: UserDataStorageTestFacade
    ) throws {
        try insertRow(in: walletId, facade: facade) { row in
            write(account, to: row)
        }
    }

    static func insertRow(
        in walletId: String,
        facade: UserDataStorageTestFacade,
        configure: @escaping (NSManagedObject) -> Void
    ) throws {
        try perform(in: facade) { context in
            let wallet = try storedWallet(walletId, in: context)
            let row = CDChainAccount(context: context)
            configure(row)
            wallet.addToChainAccounts(row)
            try context.save()
        }
    }

    static func rawRows(of walletId: String, in facade: UserDataStorageTestFacade) throws -> [RawRow] {
        try perform(in: facade) { context in
            let wallet = try storedWallet(walletId, in: context)
            let rows = wallet.chainAccounts?.allObjects as? [NSManagedObject] ?? []
            return rows.map {
                RawRow(
                    chainId: $0.value(forKey: "chainId") as? String,
                    accountId: $0.value(forKey: "accountId") as? String,
                    publicKey: $0.value(forKey: "publicKey") as? Data,
                    cryptoType: ($0.value(forKey: "cryptoType") as? NSNumber)?.int16Value ?? 0,
                    ethereumBased: ($0.value(forKey: "ethereumBased") as? NSNumber)?.boolValue,
                    ecosystem: $0.value(forKey: "ecosystem") as? String
                )
            }
            .sorted { ($0.chainId ?? "", $0.accountId ?? "") < ($1.chainId ?? "", $1.accountId ?? "") }
        }
    }

    private static func storedWallet(_ walletId: String, in context: NSManagedObjectContext) throws -> CDMetaAccount {
        let request = NSFetchRequest<CDMetaAccount>(entityName: "CDMetaAccount")
        request.predicate = NSPredicate(format: "%K == %@", #keyPath(CDMetaAccount.metaId), walletId)
        return try XCTUnwrap(try context.fetch(request).first, "Stored wallet \(walletId) was not found")
    }

    /// An in-memory store of the current model whose per-chain rows raise an Objective-C
    /// exception on every read, as a row does when Core Data cannot materialize it.
    static func makeContextWithUnreadableChainAccountRows() throws -> NSManagedObjectContext {
        let modelURL = try XCTUnwrap(UserStorageParams.modelVersion.modelURL(
            in: Bundle(for: UserDataStorageFacade.self),
            legacyModelDirectory: UserStorageParams.modelDirectory
        ))
        let model = try XCTUnwrap(NSManagedObjectModel(contentsOf: modelURL)?.copy() as? NSManagedObjectModel)
        let classes: [String: AnyClass] = [
            "CDAccountInfo": CDAccountInfo.self,
            "CDAssetVisibility": CDAssetVisibility.self,
            "CDChainAccount": UnreadableChainAccountRow.self,
            "CDChainSettings": CDChainSettings.self,
            "CDCurrency": CDCurrency.self,
            "CDCustomChainNode": CDCustomChainNode.self,
            "CDMetaAccount": CDMetaAccount.self
        ]
        for entity in model.entities {
            if let name = entity.name, let managedClass = classes[name] {
                entity.managedObjectClassName = NSStringFromClass(managedClass)
            }
        }
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        try coordinator.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil)
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        return context
    }

    static func perform<T>(
        in facade: UserDataStorageTestFacade,
        _ body: @escaping (NSManagedObjectContext) throws -> T
    ) throws -> T {
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<T, Error>?
        facade.databaseService.performAsync { context, error in
            defer { semaphore.signal() }
            do {
                if let error {
                    throw error
                }
                result = try .success(body(try XCTUnwrap(context)))
            } catch {
                result = .failure(error)
            }
        }
        semaphore.wait()
        return try XCTUnwrap(result).get()
    }
}

/// A per-chain row whose every read raises, the way a row that Core Data cannot
/// materialize does.
@objc(IK11UnreadableChainAccountRow)
final class UnreadableChainAccountRow: NSManagedObject {
    override func value(forKey key: String) -> Any? {
        // Core Data itself reads the inverse relationship while the row is attached.
        guard entity.attributesByName[key] != nil else {
            return super.value(forKey: key)
        }
        NSException(name: .objectInaccessibleException, reason: "Row \(key) cannot be read", userInfo: nil).raise()
        return nil
    }
}
