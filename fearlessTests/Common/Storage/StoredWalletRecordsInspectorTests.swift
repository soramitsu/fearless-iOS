import XCTest
@testable import fearless
import CoreData
import RobinHood
import SoraKeystore
import SSFModels
import UIKit

/// IK-11 (b): no stored wallet or account goes missing without a word. The inspector counts
/// what cannot be shown, the tracker tells the user once (again only when something new is
/// affected), and the wording says how many, that nothing was deleted and what to do.
final class StoredWalletRecordsInspectorTests: XCTestCase {
    func testReport_whenStoreHoldsWalletsThatCannotBeShown_thenCountsThemAndListsOfferedAccounts() throws {
        let facade = UserDataStorageTestFacade()
        let healthy = AccountGenerator.generateMetaAccount(generatingChainAccounts: 0)
        let hidden = ChainAccountRecordsFixture.substrateAccount(
            chainId: ChainAccountRecordsFixture.polkadotChainId, marker: 0x21
        )
        try ChainAccountRecordsFixture.save(healthy, in: facade)
        try ChainAccountRecordsFixture.insertHiddenRow(hidden, in: healthy.metaId, facade: facade)

        let damaged = AccountGenerator.generateMetaAccount(generatingChainAccounts: 0)
        try ChainAccountRecordsFixture.save(damaged, in: facade)
        try ChainAccountRecordsFixture.editWallet(damaged.metaId, in: facade) { wallet in
            wallet.setValue("not-hex", forKey: "substrateAccountId")
        }
        try ChainAccountRecordsFixture.insertTonOnlyWallet(identifier: "ton-v5", contractVersion: "v5R1", in: facade)

        let report = try fetchReport(in: facade)

        XCTAssertEqual(report.unavailableWalletCount, 2)
        XCTAssertEqual(report.wallets.map(\.metaId), [healthy.metaId])
        XCTAssertEqual(report.alternatives(for: healthy.metaId), [hidden])
        XCTAssertEqual(report.unusableChainAccountCount, 0)
    }

    func testReport_whenEveryRecordIsShown_thenItIsEmpty() throws {
        let facade = UserDataStorageTestFacade()
        try ChainAccountRecordsFixture.save(AccountGenerator.generateMetaAccount(generatingChainAccounts: 2), in: facade)

        XCTAssertEqual(try fetchReport(in: facade), .empty)
        XCTAssertEqual(
            StoredWalletRecordsNoticeTracker(settings: InMemorySettingsManager()).pendingNotices(for: .empty),
            []
        )
    }

    func testNoticeTracker_whenAcknowledged_thenShowsAgainOnlyWhenSomethingNewIsAffected() {
        let settings = InMemorySettingsManager()
        let tracker = StoredWalletRecordsNoticeTracker(settings: settings)
        let first = ChainAccountRecordsFixture.substrateAccount(chainId: "chain-a", marker: 0x31)
        let second = ChainAccountRecordsFixture.substrateAccount(chainId: "chain-b", marker: 0x32)
        let report = StoredWalletRecordsReport(
            unavailableWalletCount: 1,
            wallets: [.init(metaId: "w1", name: "One", alternatives: [first], unusable: [])]
        )

        XCTAssertEqual(
            tracker.pendingNotices(for: report),
            [.recordsNotShown(wallets: 1, chainAccounts: 0), .storedChainAccounts(walletIds: ["w1"], walletNames: ["One"])]
        )

        tracker.acknowledgeRecordsNotShown(in: report)
        tracker.acknowledgeStoredChainAccounts(in: report)
        XCTAssertEqual(tracker.pendingNotices(for: report), [])
        // The acknowledgement survives a new tracker, as after a relaunch.
        XCTAssertEqual(StoredWalletRecordsNoticeTracker(settings: settings).pendingNotices(for: report), [])

        let grown = StoredWalletRecordsReport(
            unavailableWalletCount: 2,
            wallets: [
                .init(metaId: "w1", name: "One", alternatives: [first], unusable: []),
                .init(metaId: "w2", name: "Two", alternatives: [second], unusable: [])
            ]
        )
        XCTAssertEqual(
            tracker.pendingNotices(for: grown),
            [.recordsNotShown(wallets: 2, chainAccounts: 0), .storedChainAccounts(walletIds: ["w2"], walletNames: ["Two"])]
        )
    }

    func testNoticeTracker_whenUserActsOnOneWallet_thenOtherAffectedWalletsAreStillAnnounced() {
        let tracker = StoredWalletRecordsNoticeTracker(settings: InMemorySettingsManager())
        let report = StoredWalletRecordsReport(
            unavailableWalletCount: 0,
            wallets: [
                .init(
                    metaId: "w1", name: "One",
                    alternatives: [ChainAccountRecordsFixture.substrateAccount(chainId: "chain-a", marker: 0x51)],
                    unusable: []
                ),
                .init(
                    metaId: "w2", name: "Two",
                    alternatives: [ChainAccountRecordsFixture.substrateAccount(chainId: "chain-b", marker: 0x52)],
                    unusable: []
                )
            ]
        )

        tracker.acknowledgeStoredChainAccounts(of: "w1", in: report)

        XCTAssertEqual(
            tracker.pendingNotices(for: report),
            [.storedChainAccounts(walletIds: ["w2"], walletNames: ["Two"])]
        )
    }

    func testNoticeText_whenRecordsCannotBeShown_thenSaysHowManyThatNothingWasDeletedAndWhatToDo() {
        let english = Locale(identifier: "en")

        XCTAssertNil(StoredWalletRecordsNoticeText.summary(wallets: 0, chainAccounts: 0, locale: english))
        XCTAssertEqual(
            StoredWalletRecordsNoticeText.summary(wallets: 1, chainAccounts: 2, locale: english),
            "1 stored wallet can't be shown\n2 network accounts can't be used"
        )

        let explanation = StoredWalletRecordsNoticeText.explanation(wallets: 2, chainAccounts: 1, locale: english)
        XCTAssertTrue(explanation.contains("2 wallets stored on this device can't be shown"))
        XCTAssertTrue(explanation.contains("1 network account stored in your wallets can't be used"))
        XCTAssertTrue(explanation.contains("Nothing was deleted"))
        XCTAssertTrue(explanation.contains("Do not delete the app"))
        XCTAssertTrue(explanation.contains("import it again"))
        XCTAssertFalse(explanation.lowercased().contains("reinstall"))
        XCTAssertFalse(explanation.lowercased().contains("latest build"))
    }

    func testNoticeText_inEveryShippedLocale_thenEveryStringIsTranslatedAndKeepsItsCount() throws {
        let shipped = Bundle(for: UserDataStorageFacade.self).localizations.filter { $0 != "en" && $0 != "Base" }
        XCTAssertTrue(Set(["id", "ja", "pt-PT", "ru", "tr", "vi", "zh-Hans"]).isSubset(of: Set(shipped)), "\(shipped)")
        for language in shipped {
            let locale = Locale(identifier: language)
            let summary = try XCTUnwrap(
                StoredWalletRecordsNoticeText.summary(wallets: 3, chainAccounts: 5, locale: locale),
                language
            )
            XCTAssertTrue(summary.contains("3") && summary.contains("5"), "\(language): \(summary)")
            XCTAssertFalse(summary.contains("can't be shown"), "\(language) falls back to English")
            let explanation = StoredWalletRecordsNoticeText.explanation(wallets: 1, chainAccounts: 1, locale: locale)
            XCTAssertFalse(explanation.contains("Nothing was deleted"), "\(language) falls back to English")
        }
    }

    func testWalletListNotice_whenShownAndHidden_thenSheetMakesRoomForItOrClosesTheGap() throws {
        let layout = WalletsManagmentViewLayout(type: .wallets)
        let controller = UIViewController()
        controller.view = layout
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = try XCTUnwrap(scenes.first { $0.activationState == .foregroundActive } ?? scenes.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 320, height: 640)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        // The wallet list is a bottom sheet sized by its content.
        func fittedHeight() -> CGFloat {
            layout.layoutIfNeeded()
            return layout.systemLayoutSizeFitting(
                CGSize(width: 320, height: UIView.layoutFittingCompressedSize.height),
                withHorizontalFittingPriority: .required,
                verticalFittingPriority: .fittingSizeLevel
            ).height
        }

        let withoutNotice = fittedHeight()
        let message = "1 stored wallet can't be shown\n2 network accounts can't be used"
        layout.bind(recordsNotice: message)
        let withNotice = fittedHeight()

        XCTAssertFalse(layout.recordsNoticeView.isHidden)
        XCTAssertEqual(layout.recordsNoticeView.accessibilityLabel, message)
        XCTAssertGreaterThan(layout.recordsNoticeView.frame.height, 0)
        XCTAssertGreaterThanOrEqual(layout.tableView.frame.minY, layout.recordsNoticeView.frame.maxY)
        // In the window the sheet is taller than its content; the row still keeps its own height.
        let noticeHeight = layout.recordsNoticeView.systemLayoutSizeFitting(
            CGSize(width: layout.recordsNoticeView.frame.width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height
        XCTAssertEqual(layout.recordsNoticeView.frame.height, noticeHeight, accuracy: 0.5)
        XCTAssertGreaterThanOrEqual(withNotice - withoutNotice, noticeHeight)

        layout.bind(recordsNotice: nil)

        XCTAssertTrue(layout.recordsNoticeView.isHidden)
        XCTAssertEqual(fittedHeight(), withoutNotice, accuracy: 0.5)
    }

    func testSelectedWalletSave_whenModelCarriesAnAccountTheStoreKeepsUnused_thenTheAppHoldsWhatIsStored() throws {
        let facade = UserDataStorageTestFacade()
        let settings = SelectedWalletSettings(storageFacade: facade, operationQueue: OperationQueue())
        let wallet = AccountGenerator.generateMetaAccount(generatingChainAccounts: 0)
        let hidden = ChainAccountRecordsFixture.substrateAccount(
            chainId: ChainAccountRecordsFixture.polkadotChainId, marker: 0x41
        )
        let inUse = ChainAccountRecordsFixture.substrateAccount(
            chainId: ChainAccountRecordsFixture.kusamaChainId, marker: 0x42
        )
        try ChainAccountRecordsFixture.save(wallet.replacingChainAccounts([inUse]), in: facade)
        try ChainAccountRecordsFixture.insertHiddenRow(hidden, in: wallet.metaId, facade: facade)

        let saved = try save(wallet.replacingChainAccounts([inUse, hidden]).replacingName("Renamed"), in: settings)

        XCTAssertEqual(saved.chainAccounts, [inUse])
        XCTAssertEqual(saved.name, "Renamed")
        XCTAssertEqual(settings.value?.chainAccounts, [inUse])
        XCTAssertEqual(try ChainAccountRecordsFixture.wallets(in: facade).first?.chainAccounts, [inUse])
    }
}

// MARK: - Helpers

private extension StoredWalletRecordsInspectorTests {
    func fetchReport(in facade: StorageFacadeProtocol) throws -> StoredWalletRecordsReport {
        let operation = StoredWalletRecordsInspector(storageFacade: facade).fetchReportOperation()
        OperationQueue().addOperations([operation], waitUntilFinished: true)
        return try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
    }

    func save(_ wallet: MetaAccountModel, in settings: SelectedWalletSettings) throws -> MetaAccountModel {
        let completed = expectation(description: "selected wallet save completes")
        var saveResult: Result<MetaAccountModel, Error>?
        settings.save(value: wallet, runningCompletionIn: .main) { result in
            saveResult = result
            completed.fulfill()
        }
        wait(for: [completed], timeout: 10)
        return try XCTUnwrap(saveResult).get()
    }
}

extension ChainAccountRecordsFixture {
    static func editWallet(
        _ walletId: String,
        in facade: UserDataStorageTestFacade,
        edit: @escaping (NSManagedObject) -> Void
    ) throws {
        try perform(in: facade) { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: "CDMetaAccount")
            request.predicate = NSPredicate(format: "metaId == %@", walletId)
            edit(try XCTUnwrap(try context.fetch(request).first))
            try context.save()
        }
    }

    /// A TON-only wallet as the 4.0.x line stored it; this release supports only v4R2 ones.
    static func insertTonOnlyWallet(
        identifier: String,
        contractVersion: String,
        in facade: UserDataStorageTestFacade
    ) throws {
        try perform(in: facade) { context in
            let wallet = CDMetaAccount(context: context)
            wallet.metaId = identifier
            wallet.name = "TON wallet"
            wallet.isSelected = false
            wallet.order = 50
            wallet.canExportEthereumMnemonic = false
            wallet.hasBackup = false
            wallet.favouriteChainIds = NSArray()
            wallet.setValue(false, forKey: "zeroBalanceAssetsHidden")
            wallet.setValue(Data(repeating: 0x41, count: 36), forKey: "tonAddress")
            wallet.setValue(Data(repeating: 0x42, count: 32), forKey: "tonPublicKey")
            wallet.setValue(contractVersion, forKey: "tonContractVersion")
            try context.save()
        }
    }
}
