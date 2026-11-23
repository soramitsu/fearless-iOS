import AppKit
import CoreGraphics
import DesignSystem
import Foundation
import Testing
import WalletCore
@testable import WalletPreviewSupport
@testable import WalletUI

@Suite("Preview services")
struct PreviewSupportTests {
    @Test func bip39MatchesThePublishedTestVector() {
        #expect(PreviewWalletServices.wordList.count == 2048)
        #expect(PreviewWalletServices.samplePhrase(.words12).joined(separator: " ") == "ozone drill grab fiber curtain grace pudding thank cruise elder eight picnic")
        #expect(PreviewWalletServices.samplePhrase(.words18).joined(separator: " ") == "gravity machine north sort system female filter attitude volume fold club stay feature office ecology stable narrow fog")
        for length in MnemonicLength.allCases {
            let phrase = PreviewWalletServices.samplePhrase(length)
            #expect(phrase.count == length.rawValue)
            #expect(PreviewBIP39.validate(phrase) == .valid)
        }
        #expect(PreviewBIP39.validate(["ozone"]) == .invalidLength(count: 1))
        var phrase = PreviewWalletServices.samplePhrase(.words12)
        phrase[2] = "grabb"
        #expect(PreviewBIP39.validate(phrase) == .unknownWords(indices: [2]))
    }

    @Test func sampleAddressesRoundTripAndValidateOnTheirNetworks() {
        for account in [PreviewSampleData.alice, PreviewSampleData.bob, PreviewSampleData.charlie] {
            for (prefix, address) in account.addresses {
                let bytes = PreviewAddressCodec.base58Decode(address)
                #expect(bytes?.count == 35)
                #expect(bytes?.first == UInt8(prefix))
                #expect(bytes.map { Array($0[1..<33]) } == account.publicKey)
                #expect(bytes.map(PreviewAddressCodec.base58Encode) == address)
            }
            #expect(PreviewAddressCodec.validate(account.polkadot, on: PreviewCatalog.polkadot) == .valid(normalized: account.polkadot))
            #expect(PreviewAddressCodec.validate(account.kusama, on: PreviewCatalog.kusama) == .valid(normalized: account.kusama))
            if case .wrongNetwork = PreviewAddressCodec.validate(account.kusama, on: PreviewCatalog.polkadot) {} else {
                Issue.record("a Kusama address on Polkadot must be a wrong-network result")
            }
        }
        #expect(PreviewAddressCodec.validate("", on: PreviewCatalog.polkadot) == .empty)
        #expect(PreviewAddressCodec.validate(PreviewSampleData.evmAccount0, on: PreviewCatalog.ethereum) == .valid(normalized: PreviewSampleData.evmAccount0))
        if case .invalid = PreviewAddressCodec.validate("0x1234", on: PreviewCatalog.ethereum) {} else {
            Issue.record("a short hex string is not an address")
        }
    }

    @Test func theCatalogListsTheShippedNetworks() async {
        let services = PreviewWalletServices.make(scenario: PreviewScenario.standard.instant())
        let chains = await services.catalog.chains()
        #expect(chains.map(\.name) == ["Polkadot", "Polkadot Asset Hub", "Kusama", "Kusama Asset Hub", "Westend", "Ethereum", "BNB Smart Chain", "Polygon", "Sepolia"])
        #expect(chains.filter { $0.isTestnet }.map { $0.name } == ["Westend", "Sepolia"])
        let assets = await services.catalog.assets()
        #expect(Set(assets.map(\.id)).count == assets.count)
        #expect(assets.allSatisfy { asset in chains.contains { $0.id == asset.chainID } })
        #expect(chains.allSatisfy { chain in assets.contains { $0.id == chain.nativeAssetID } })
    }

    @Test func vaultStatesAreStreamedInOrder() async throws {
        let services = PreviewWalletServices.make(scenario: PreviewScenario.firstRun.instant())
        var iterator = services.vault.stateUpdates().makeAsyncIterator()
        #expect(await iterator.next() == .uninitialized)
        await #expect(throws: WalletError.passwordTooWeak) {
            try await services.vault.initialize(password: "password")
        }
        try await services.vault.initialize(password: PreviewWalletServices.samplePassword)
        #expect(await iterator.next() == .unlocked)
        await services.vault.lock()
        #expect(await iterator.next() == .locked)
        try await services.vault.eraseAllData()
        #expect(await iterator.next() == .uninitialized)
    }

    @Test func aCreatedPhraseIsNotBackedUpAndAnImportedOneIs() async throws {
        let services = PreviewWalletServices.make(scenario: PreviewScenario.emptyWalletList.instant())
        let created = try await services.wallets.addWallet(
            name: "New", source: .created(words: PreviewWalletServices.samplePhrase(.words12), options: .standard)
        )
        #expect(created.origin == .created)
        #expect(!created.isBackedUp)
        #expect(created.hasRecoveryPhrase)
        let imported = try await services.wallets.addWallet(
            name: "Old", source: .mnemonic(words: PreviewWalletServices.samplePhrase(.words24), options: .standard)
        )
        #expect(imported.origin == .mnemonic)
        #expect(imported.isBackedUp)
        try await services.wallets.markBackedUp(created.id)
        #expect(try await services.wallets.wallets().allSatisfy { $0.isBackedUp })
        await #expect(throws: WalletError.invalidMnemonic) {
            _ = try await services.wallets.previewAddresses(for: .created(words: ["ozone"], options: .standard))
        }
    }

    @Test func backupsCarryDerivationOptionsAndAccountsNeverShowThePassword() async throws {
        let services = PreviewWalletServices.make(scenario: PreviewScenario.emptyWalletList.instant())
        let options = DerivationOptions(substrateCryptoType: .ed25519, substrateDerivationPath: "//hard/soft///secret-word", evmDerivationPath: "m/44'/60'/0'/0/7")
        let wallet = try await services.wallets.addWallet(
            name: "Custom", source: .mnemonic(words: PreviewWalletServices.samplePhrase(.words12), options: options)
        )
        let substrate = try #require(wallet.account(for: .substrate))
        #expect(substrate.derivationPath == "//hard/soft", "the password part never appears in the public account")
        #expect(substrate.cryptoType == .ed25519)

        let backup = try await services.wallets.exportMnemonic(wallet.id, approval: .password(PreviewWalletServices.samplePassword))
        #expect(backup.words == PreviewWalletServices.samplePhrase(.words12))
        #expect(backup.options == options)
        #expect(backup.needsDerivationDetails)

        let plain = try await services.wallets.addWallet(
            name: "Plain", source: .created(words: PreviewWalletServices.samplePhrase(.words24), options: .standard)
        )
        let plainBackup = try await services.wallets.exportMnemonic(plain.id, approval: .password(PreviewWalletServices.samplePassword))
        #expect(!plainBackup.needsDerivationDetails)
        #expect(plain.account(for: .substrate)?.derivationPath == nil)
    }

    @Test func scenariosSwitchTheFailures() async throws {
        let empty = PreviewWalletServices.make(scenario: PreviewScenario.emptyWalletList.instant())
        #expect(try await empty.wallets.wallets().isEmpty)
        #expect(await empty.vault.state() == .unlocked)

        let locked = PreviewWalletServices.make(scenario: PreviewScenario.locked.instant())
        #expect(await locked.vault.state() == .locked)
        await #expect(throws: WalletError.vaultLocked) {
            _ = try await locked.wallets.exportMnemonic(PreviewSampleData.mainWalletID, approval: .password(PreviewWalletServices.samplePassword))
        }

        let failing = PreviewWalletServices.make(scenario: PreviewScenario.balanceFailure.instant())
        let results = await failing.balances.balances(of: PreviewSampleData.mainWalletID, assets: [PreviewCatalog.ksm.id, PreviewCatalog.dot.id])
        #expect(throws: WalletError.self) { try results[PreviewCatalog.ksm.id]?.get() }
        #expect(try results[PreviewCatalog.dot.id]?.get().total == amount("1250.5", 10))
    }
}

@MainActor
@Suite("Design system")
struct DesignSystemTests {
    @Test func addressesShortenAndGroup() {
        let address = PreviewSampleData.alice.polkadot
        #expect(AddressFormat.truncated(address) == "15oF4uVJ…Hr6Sp5")
        #expect(AddressFormat.truncated("short") == "short")
        #expect(AddressFormat.grouped("abcdefghij") == "abcd efgh ij")
        #expect(AddressFormat.grouped(address).replacingOccurrences(of: " ", with: "") == address)
        #expect(AddressFormat.webURL(URL(string: "https://polkadot.subscan.io/x")) != nil)
        #expect(AddressFormat.webURL(URL(string: "file:///etc/passwd")) == nil)
        #expect(AddressFormat.webURL(nil) == nil)
    }

    @Test func moneyFormatsFollowTheLocale() {
        let us = Locale(identifier: "en_US")
        #expect(Money.fiat(Decimal(string: "17768.259")!, currency: .usd, locale: us) == "$17,768.26")
        #expect(Money.fiat(Decimal(string: "0.2145")!, currency: .usd, locale: us) == "$0.2145")
        #expect(Money.fiat(0, currency: .usd, locale: us) == "$0.00")
        #expect(Money.fiat(Decimal(string: "1234.5")!, currency: .jpy, locale: us) == "¥1,235" || Money.fiat(Decimal(string: "1234.5")!, currency: .jpy, locale: us) == "¥1,234")
        #expect(Money.fiat(Decimal(string: "1234.5")!, currency: .eur, locale: Locale(identifier: "de_DE")).contains("1.234,50"))
        #expect(Money.percent(Decimal(string: "2.34")!, locale: us) == "+2.34%")
        #expect(Money.percent(Decimal(string: "-1.2")!, locale: us).contains("1.20%"))
        #expect(Money.share(Decimal(string: "0.3642")!, locale: us) == "36.4%")
        #expect(Money.token(amount("1250.5", 10), symbol: "DOT", locale: us) == "1,250.5 DOT")
        let digits = Money.displayDigits(isStablecoin: true, decimals: 6)
        #expect(digits.minimum == 2 && digits.maximum == 2)
        #expect(Money.displayDigits(isStablecoin: false, decimals: 18).maximum == 4)
    }

    @Test func secretsOnThePasteboardAreConcealedAndCleared() async {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let clipboard = Clipboard(pasteboard: pasteboard)

        clipboard.copy("an address")
        #expect(clipboard.string() == "an address")
        #expect(!clipboard.isConcealed)

        clipboard.copyConcealed("twelve secret words", clearAfter: 0.05)
        #expect(clipboard.isConcealed)
        #expect(pasteboard.types?.contains(NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")) == true)
        #expect(clipboard.string() == "twelve secret words")
        #expect(await waitUntil(timeout: .seconds(5)) { clipboard.string() == nil })
    }

    @Test func aLaterCopyIsNotClearedByAnEarlierSecret() async {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let clipboard = Clipboard(pasteboard: pasteboard)
        clipboard.copyConcealed("secret", clearAfter: 60)
        let secretCount = clipboard.changeCount
        pasteboard.clearContents()
        pasteboard.setString("something the user copied", forType: .string)
        clipboard.clearIfUnchanged(since: secretCount)
        #expect(clipboard.string() == "something the user copied")
        clipboard.clearIfUnchanged(since: clipboard.changeCount)
        #expect(clipboard.string() == nil)
    }

    @Test func qrCodesAreGeneratedForAddresses() throws {
        let image = try #require(QRCode.image(for: PreviewSampleData.alice.polkadot))
        #expect(image.width == image.height)
        #expect(image.width >= 21)
        #expect(QRCode.image(for: "") == nil)
        #expect(QRCode.image(for: PreviewSampleData.evmAccount0)?.width != nil)
    }

    @Test func bundledAssetsLoad() {
        #expect(BrandFont.isAvailable(.bold))
        #expect(BrandFont.isAvailable(.regular))
        #expect(BrandFont.licenceText?.contains("SIL Open Font License") == true)
        for chain in PreviewCatalog.chains {
            #expect(IconLibrary.chainGlyph(named: chain.iconName) != nil, "no glyph for \(chain.name)")
        }
        for asset in PreviewCatalog.assets {
            #expect(asset.tokenIconName != nil, "the catalog names a token icon for \(asset.symbol)")
            #expect(IconLibrary.tokenIcon(named: asset.tokenIconName) != nil, "no bundled token icon for \(asset.symbol)")
        }
        #expect(IconLibrary.tokenIcon(named: "usdt") != nil, "lookups ignore case")
        #expect(IconLibrary.tokenIcon(named: nil) == nil)
        #expect(IconLibrary.tokenIcon(named: "NOPE") == nil)
        #expect(IconLibrary.chainGlyph(named: "polkadot") != nil, "lookups ignore case")
        #expect(IconLibrary.chainGlyph(named: "no-such-chain") == nil)
        #expect(IconLibrary.chainGlyph(named: nil) == nil)
        #expect(NSImage.fearlessMenuBarCrest()?.isTemplate == true)
    }

    @Test func paleDiscsGetADarkGlyph() throws {
        #expect(try #require(IconContrast.relativeLuminance(hex: "#FFFFFF")) == 1)
        #expect(try #require(IconContrast.relativeLuminance(hex: "000000")) == 0)
        #expect(IconContrast.relativeLuminance(hex: "#12") == nil)
        #expect(IconContrast.relativeLuminance(hex: nil) == nil)

        // A white or pastel accent would hide a white glyph: it gets ink instead.
        #expect(IconContrast.needsDarkGlyph(accentHex: "#FFFFFF"))
        #expect(IconContrast.needsDarkGlyph(accentHex: "#F4F4F4"))
        #expect(IconContrast.needsDarkGlyph(accentHex: "#FFE9BE"))
        // Brand colours and dark discs keep the white glyph.
        for hex in ["#E6007A", "#000000", "#2B2B33", "#627EEA", "#8247E5", "#DA68A7", "#C99400"] {
            #expect(!IconContrast.needsDarkGlyph(accentHex: hex), "\(hex) should keep a white glyph")
        }
        #expect(!IconContrast.needsDarkGlyph(accentHex: nil), "without a catalog colour the bundled fallback is used")

        // Whatever the catalog says, the extremes stay clearly readable.
        for hex in ["#FFFFFF", "#F4F4F4", "#000000", "#120A2E", "#E6007A"] {
            let contrast = try #require(IconContrast.glyphContrast(accentHex: hex))
            #expect(contrast >= 3, "\(hex) glyph contrast is only \(contrast)")
        }
        // No colour can make the glyph vanish: sweep the grey ramp.
        for level in stride(from: 0, through: 255, by: 5) {
            let hex = String(format: "#%02X%02X%02X", level, level, level)
            let contrast = try #require(IconContrast.glyphContrast(accentHex: hex))
            #expect(contrast >= 1.6, "\(hex) glyph contrast is only \(contrast)")
        }
    }

    @Test func chartColoursAreNeverCycled() {
        for slot in 0..<ChartPalette.slotCount {
            #expect(ChartPalette.color(slot: slot) != nil)
        }
        #expect(ChartPalette.color(slot: ChartPalette.slotCount) == nil, "past the last slot a part is drawn as Other")
        #expect(ChartPalette.color(slot: -1) == nil)
    }

    @Test func sealStagesAreOrdered() {
        #expect(SealStage.allCases == [.idle, .ready, .signed, .sent, .accepted, .finalized])
        #expect(SealStage.signed < SealStage.sent)
        #expect(max(SealStage.accepted, .signed) == .accepted)
        #expect(SealStage.allCases.allSatisfy { !$0.spokenDescription.isEmpty })
    }

    @Test func galleryScreensHaveFileNames() {
        #expect(GalleryScreen.sendReview.slug == "send-review")
        #expect(GalleryScreen.onboardingJSONImport.slug == "onboarding-json-import")
        #expect(GalleryScreen.onboardingTouchID.slug == "onboarding-touch-id")
        #expect(Set(GalleryScreen.allCases.map(\.slug)).count == GalleryScreen.allCases.count)
    }
}

@MainActor
@Suite("Gallery")
struct GalleryTests {
    private let inputs = GalleryHost.Inputs(
        password: PreviewWalletServices.samplePassword,
        recipient: PreviewSampleData.sampleRecipientPolkadot,
        wrongNetworkRecipient: PreviewSampleData.sampleRecipientKusama,
        importWords: PreviewWalletServices.samplePhrase(.words12)
    )

    private func scenario(for screen: GalleryScreen) -> PreviewScenario {
        switch screen {
        case .sendProgress: return PreviewScenario(transferOutcome: .stallsAfterBroadcast).instant()
        case .sendFailed: return PreviewScenario.transferFailsAtInclusion.instant()
        case .sendOutcomeUnknown: return PreviewScenario.transferOutcomeUnknown.instant()
        default:
            switch screen.start {
            case .firstRun: return PreviewScenario.firstRun.instant()
            case .locked: return PreviewScenario.locked.instant()
            case .unlockedEmpty: return PreviewScenario.emptyWalletList.instant()
            case .unlocked: return PreviewScenario.standard.instant()
            }
        }
    }

    @Test(arguments: GalleryScreen.allCases)
    func everyScreenReachesItsState(_ screen: GalleryScreen) async {
        let host = GalleryHost(screen: screen, services: PreviewWalletServices.make(scenario: scenario(for: screen)), settings: makeSettings(), inputs: inputs)
        #expect(await host.prepare(), "\(screen.rawValue) did not reach its state")
    }
}
