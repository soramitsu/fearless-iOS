import XCTest
import UIKit
import SoraFoundation
@testable import fearless

final class CovJMxWalletsView: UIViewController, WalletsManagmentViewInput {
    var viewModels: [[WalletsManagmentCellViewModel]] = []
    var notices: [String?] = []
    func didReceiveViewModels(_ viewModels: [WalletsManagmentCellViewModel]) { self.viewModels.append(viewModels) }
    func didReceiveRecordsNotice(_ notice: String?) { notices.append(notice) }
}

final class CovJMxWalletsInteractor: WalletsManagmentInteractorInput {
    weak var output: WalletsManagmentInteractorOutput?
    var selected: [ManagedMetaAccountModel] = []
    var fetches = 0
    func setup(with output: WalletsManagmentInteractorOutput) { self.output = output }
    func select(wallet: ManagedMetaAccountModel) { selected.append(wallet) }
    func fetchWalletsFromRepo() { fetches += 1 }
}

final class CovJMxWalletsRouter: CovJSheetSpy, WalletsManagmentRouterInput {
    var options: [(String, WalletOptionModuleOutput?)] = []
    var dismissals = 0

    func showOptions(from _: WalletsManagmentViewInput?, metaAccount: ManagedMetaAccountModel, delegate: WalletOptionModuleOutput?) {
        options.append((metaAccount.info.metaId, delegate))
    }

    func dissmis(view _: WalletsManagmentViewInput?, dissmisCompletion: @escaping () -> Void) {
        dismissals += 1
        dissmisCompletion()
    }
}

final class CovJMxWalletsViewModelFactory: WalletsManagmentViewModelFactoryProtocol {
    var calls: [(wallets: Int, balances: Int)] = []

    func buildViewModel(
        viewType _: WalletsManagmentType,
        from wallets: [ManagedMetaAccountModel],
        balances: [MetaAccountId: WalletBalanceInfo],
        locale _: Locale
    ) -> [WalletsManagmentCellViewModel] {
        calls.append((wallets.count, balances.count))
        return wallets.map {
            WalletsManagmentCellViewModel(
                isSelected: $0.isSelected,
                walletName: $0.info.name,
                fiatBalance: nil,
                dayChange: nil
            )
        }
    }
}

final class CovJMxWalletsModuleOutput: WalletsManagmentModuleOutput {
    var events: [String] = []
    var imports: [AccountImportSource] = []
    var selections: [(String, Int)] = []
    func showAddNewWallet() { events.append("new") }
    func showImportWallet(defaultSource: AccountImportSource) { imports.append(defaultSource) }
    func showImportGoogle() { events.append("google") }
    func showGetPreinstalledWallet() { events.append("preinstalled") }
    func selectedWallet(_ wallet: MetaAccountModel, for contextTag: Int) { selections.append((wallet.metaId, contextTag)) }
}

final class CovJMxWalletsManagmentPresenterTests: XCTestCase {
    private let locale = Locale(identifier: "en")
    private var view = CovJMxWalletsView()
    private var interactor = CovJMxWalletsInteractor()
    private var router = CovJMxWalletsRouter()
    private var factory = CovJMxWalletsViewModelFactory()
    private var output = CovJMxWalletsModuleOutput()

    override func setUp() {
        super.setUp()
        view = CovJMxWalletsView()
        interactor = CovJMxWalletsInteractor()
        router = CovJMxWalletsRouter()
        factory = CovJMxWalletsViewModelFactory()
        output = CovJMxWalletsModuleOutput()
    }

    func testLoadSetsUpInteractorAndWalletsReachTheView() throws {
        let presenter = try makePresenter()
        let wallets = makeWallets()

        presenter.didLoad(view: view)
        XCTAssertTrue(interactor.output === presenter)

        presenter.didReceiveWallets(.success(wallets))
        XCTAssertTrue(CovJWait.until { self.view.viewModels.last?.count == 2 })
        XCTAssertEqual(view.viewModels.last?.map(\.walletName), wallets.map(\.info.name))
        XCTAssertEqual(view.viewModels.last?.map(\.isSelected), [true, false])

        let callsBefore = factory.calls.count
        presenter.didReceiveWallets(.failure(CovJError()))
        presenter.didReceiveWalletBalances(.failure(CovJError()))
        CovJWait.drain()
        XCTAssertEqual(factory.calls.count, callsBefore)

        presenter.didReceiveWalletBalances(.success([:]))
        XCTAssertEqual(factory.calls.count, callsBefore + 1)
        XCTAssertEqual(factory.calls.last?.wallets, 2)
    }

    func testTappingWalletsSelectsThemForTheContextAndIgnoresMissingRows() throws {
        let presenter = try makePresenter(contextTag: 42)
        let wallets = makeWallets()
        presenter.didLoad(view: view)
        presenter.didReceiveWallets(.success(wallets))

        presenter.didTap(on: IndexPath(row: 1, section: 0))
        presenter.didTap(on: IndexPath(row: 5, section: 0))
        presenter.didTapOptions(for: IndexPath(row: 0, section: 0))
        presenter.didTapOptions(for: IndexPath(row: 9, section: 0))

        XCTAssertEqual(output.selections.map(\.0), [wallets[1].info.metaId])
        XCTAssertEqual(output.selections.map(\.1), [42])
        XCTAssertEqual(interactor.selected, [wallets[1]])
        XCTAssertEqual(router.options.map(\.0), [wallets[0].info.metaId])
        XCTAssertTrue(router.options.first?.1 === presenter)
    }

    func testNavigationActionsDismissAndForwardToTheModuleOutput() throws {
        let presenter = try makePresenter()
        presenter.didLoad(view: view)

        presenter.didTapNewWallet()
        presenter.didTapClose()
        presenter.didCompleteSelection()
        presenter.didReceive(error: CovJError("boom"))
        presenter.walletWasRemoved()

        XCTAssertEqual(router.dismissals, 3)
        XCTAssertEqual(output.events, ["new"])
        XCTAssertEqual(router.errors.compactMap { $0 as? CovJError }, [CovJError("boom")])
        XCTAssertEqual(interactor.fetches, 1)
    }

    func testImportSheetOffersEverySourceAndRoutesEachChoice() throws {
        let presenter = try makePresenter()
        presenter.didLoad(view: view)
        // The preinstalled-wallet import is compiled out, so even an enabling remote config leaves it hidden.
        presenter.didReceiveFeatureToggleConfig(result: .success(FeatureToggleConfig(pendulumCaseEnabled: true, nftEnabled: nil)))
        presenter.didReceiveFeatureToggleConfig(result: .failure(CovJError()))
        presenter.didReceiveFeatureToggleConfig(result: nil)

        presenter.didTapImportWallet()

        let sheet = try XCTUnwrap(router.sheets.last)
        let languages = locale.rLanguages
        XCTAssertEqual(sheet.title, R.string.localizable.googleBackupChoiceTitle(preferredLanguages: languages))
        XCTAssertNil(sheet.message)
        XCTAssertNil(sheet.closeAction)
        XCTAssertEqual(sheet.actions.map(\.title), [
            R.string.localizable.googleBackupChoiceMnemonic(preferredLanguages: languages),
            R.string.localizable.googleBackupChoiceRaw(preferredLanguages: languages),
            R.string.localizable.googleBackupChoiceJson(preferredLanguages: languages),
            R.string.localizable.googleBackupChoiceGoogle(preferredLanguages: languages),
            R.string.localizable.commonCancel(preferredLanguages: languages)
        ])
        XCTAssertNil(sheet.actions.last?.handler)

        sheet.actions.dropLast().forEach { $0.handler?() }

        XCTAssertEqual(output.imports, [.mnemonic, .seed, .keystore])
        XCTAssertEqual(output.events, ["google"])
        XCTAssertEqual(router.dismissals, 4)
    }

    func testRecordsNoticeSummarisesReportAndItsImportActionReopensTheImportChoices() throws {
        let presenter = try makePresenter()
        presenter.didLoad(view: view)
        let report = StoredWalletRecordsReport(unavailableWalletCount: 2, wallets: [])

        presenter.didReceiveWalletRecordsReport(report)

        XCTAssertEqual(view.notices.last, StoredWalletRecordsNoticeText.summary(wallets: 2, chainAccounts: 0, locale: locale))
        XCTAssertNotNil(view.notices.last ?? nil)

        presenter.didTapRecordsNotice()

        let sheet = try XCTUnwrap(router.sheets.last)
        let languages = locale.rLanguages
        XCTAssertEqual(sheet.title, R.string.localizable.walletRecordsSheetTitle(preferredLanguages: languages))
        XCTAssertEqual(sheet.message, StoredWalletRecordsNoticeText.explanation(wallets: 2, chainAccounts: 0, locale: locale))
        XCTAssertEqual(sheet.closeAction, R.string.localizable.commonClose(preferredLanguages: languages))
        XCTAssertEqual(sheet.actions.map(\.title), [
            R.string.localizable.importWallet(preferredLanguages: languages),
            RecoveryText.string("export")
        ])
        XCTAssertNotNil(sheet.icon)
        let completion = try XCTUnwrap(sheet.dismissCompletion)

        // Closing without choosing does nothing.
        completion()
        XCTAssertEqual(router.sheets.count, 1)

        sheet.actions.first?.handler?()
        completion()

        XCTAssertEqual(router.sheets.count, 2)
        XCTAssertEqual(router.sheets.last?.title, R.string.localizable.googleBackupChoiceTitle(preferredLanguages: languages))
    }

    func testRecordsNoticeExportWithoutAViewPresentsNothingElse() throws {
        let presenter = try makePresenter()
        presenter.didReceiveWalletRecordsReport(StoredWalletRecordsReport(unavailableWalletCount: 1, wallets: []))

        presenter.didTapRecordsNotice()
        let sheet = try XCTUnwrap(router.sheets.last)
        sheet.actions.last?.handler?()
        sheet.dismissCompletion?()

        XCTAssertEqual(router.sheets.count, 1)
        XCTAssertTrue(view.notices.isEmpty)
    }

    func testEmptyReportClearsNoticeAndLocalizationRebuildsTheList() throws {
        let presenter = try makePresenter()
        presenter.didLoad(view: view)
        presenter.didReceiveWalletRecordsReport(.empty)
        XCTAssertEqual(view.notices.count, 1)
        XCTAssertNil(view.notices.last ?? nil)

        let calls = factory.calls.count
        presenter.applyLocalization()

        XCTAssertEqual(factory.calls.count, calls + 1)
        XCTAssertEqual(view.notices.count, 2)
    }

    // MARK: - Helpers

    private func makePresenter(contextTag: Int = 0) throws -> WalletsManagmentPresenter {
        WalletsManagmentPresenter(
            viewType: .wallets,
            contextTag: contextTag,
            viewModelFactory: factory,
            logger: Logger.shared,
            interactor: interactor,
            router: router,
            moduleOutput: output,
            localizationManager: try XCTUnwrap(LocalizationManager(localization: "en"))
        )
    }

    private func makeWallets() -> [ManagedMetaAccountModel] {
        [
            ManagedMetaAccountModel(info: AccountGenerator.generateMetaAccount(), isSelected: true, order: 1),
            ManagedMetaAccountModel(info: AccountGenerator.generateMetaAccount(), isSelected: false, order: 2)
        ]
    }
}

final class CovJMxWalletsViewOutput: WalletsManagmentViewOutput {
    var events: [String] = []
    var taps: [IndexPath] = []
    var options: [IndexPath] = []
    func didLoad(view _: WalletsManagmentViewInput) { events.append("load") }
    func didTapNewWallet() { events.append("new") }
    func didTapImportWallet() { events.append("import") }
    func didTapOptions(for indexPath: IndexPath) { options.append(indexPath) }
    func didTapClose() { events.append("close") }
    func didTap(on indexPath: IndexPath) { taps.append(indexPath) }
    func didTapRecordsNotice() { events.append("notice") }
}

final class CovJMxWalletsManagmentViewTests: XCTestCase {
    func testControllerListsWalletsAndForwardsEveryAction() throws {
        let output = CovJMxWalletsViewOutput()
        let manager = try XCTUnwrap(LocalizationManager(localization: "en"))
        let controller = WalletsManagmentViewController(viewType: .wallets, output: output, localizationManager: manager)
        let window = try CovJViewFixture.host(controller)
        defer { window.isHidden = true }
        let root = try XCTUnwrap(controller.view as? WalletsManagmentViewLayout)
        let languages = manager.selectedLocale.rLanguages

        XCTAssertEqual(output.events, ["load"])
        XCTAssertEqual(root.titleLabel.text, R.string.localizable.commonWallet(preferredLanguages: languages))
        XCTAssertEqual(root.importWalletButton.imageWithTitleView?.title, R.string.localizable.importWallet(preferredLanguages: languages))

        controller.didReceiveViewModels([
            WalletsManagmentCellViewModel(isSelected: true, walletName: "Main", fiatBalance: nil, dayChange: nil),
            WalletsManagmentCellViewModel(
                isSelected: false, walletName: "Savings", fiatBalance: "$5.00",
                dayChange: NSAttributedString(string: "+1%"), balanceCaption: "incl. hidden"
            )
        ])
        let table = root.tableView
        XCTAssertEqual(controller.numberOfSections(in: table), 1)
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 2)

        for row in 0 ..< 2 {
            let indexPath = IndexPath(row: row, section: 0)
            let cell = try XCTUnwrap(controller.tableView(table, cellForRowAt: indexPath) as? WalletsManagmentTableCell)
            controller.tableView(table, willDisplay: cell, forRowAt: indexPath)
            let texts = CovJViewFixture.descendants(UILabel.self, in: cell).compactMap(\.text)
            XCTAssertTrue(texts.contains(row == 0 ? "Main" : "Savings"))
            if row == 1 {
                XCTAssertTrue(texts.contains("$5.00"))
                XCTAssertTrue(texts.contains("incl. hidden"))
            }
        }
        controller.tableView(table, willDisplay: UITableViewCell(), forRowAt: IndexPath(row: 0, section: 0))
        controller.tableView(table, didSelectRowAt: IndexPath(row: 1, section: 0))
        controller.didTapOptionsCell(with: nil)
        controller.didTapOptionsCell(with: IndexPath(row: 0, section: 0))

        root.addNewWalletButton.sendActions(for: .touchUpInside)
        root.importWalletButton.sendActions(for: .touchUpInside)
        root.backButton.sendActions(for: .touchUpInside)
        root.recordsNoticeView.sendActions(for: .touchUpInside)

        XCTAssertEqual(output.taps, [IndexPath(row: 1, section: 0)])
        XCTAssertEqual(output.options, [IndexPath(row: 0, section: 0)])
        XCTAssertEqual(output.events, ["load", "new", "import", "close", "notice"])
    }

    func testRecordsNoticeShowsAndHidesAndSelectionTitleDiffers() throws {
        let manager = try XCTUnwrap(LocalizationManager(localization: "en"))
        let controller = WalletsManagmentViewController(
            viewType: .selectYourWallet(selectedWalletId: nil),
            output: CovJMxWalletsViewOutput(),
            localizationManager: manager
        )
        let window = try CovJViewFixture.host(controller)
        defer { window.isHidden = true }
        let root = try XCTUnwrap(controller.view as? WalletsManagmentViewLayout)

        XCTAssertEqual(
            root.titleLabel.text,
            R.string.localizable.walletManagmentSelectWalletTitle(preferredLanguages: manager.selectedLocale.rLanguages)
        )
        controller.didReceiveRecordsNotice("2 wallets are not shown")
        XCTAssertFalse(root.recordsNoticeView.isHidden)
        XCTAssertEqual(root.recordsNoticeView.titleLabel.text, "2 wallets are not shown")
        XCTAssertEqual(root.recordsNoticeView.accessibilityLabel, "2 wallets are not shown")

        controller.didReceiveRecordsNotice(nil)
        XCTAssertTrue(root.recordsNoticeView.isHidden)
        XCTAssertNil(root.recordsNoticeView.titleLabel.text)
    }

    func testRouterDismissesThePresentedListAndCallsBack() throws {
        let root = UIViewController()
        let window = try CovJViewFixture.host(root)
        defer { window.isHidden = true }
        let list = CovJMxWalletsView()
        root.present(list, animated: false)
        XCTAssertTrue(CovJWait.until { root.presentedViewController === list && !list.isBeingPresented })
        var completions = 0

        WalletsManagmentRouter().dissmis(view: list) { completions += 1 }

        XCTAssertTrue(CovJWait.until(timeout: 3) { completions == 1 })
        XCTAssertNil(root.presentedViewController)
    }
}

final class CovJMxWalletsViewModelFactoryTests: XCTestCase {
    private let locale = Locale(identifier: "en")
    /// The default currency (US dollar), named through a wallet to keep `SSFModels` out of this file.
    private let currency = AccountGenerator.generateMetaAccount().selectedCurrency

    func testCardsDistinguishMissingZeroAndFundedBalances() throws {
        let missing = ManagedMetaAccountModel(info: AccountGenerator.generateMetaAccount(), isSelected: true)
        let empty = ManagedMetaAccountModel(info: AccountGenerator.generateMetaAccount())
        let funded = ManagedMetaAccountModel(info: AccountGenerator.generateMetaAccount())
        let balances = [
            empty.info.metaId: balance(total: 0, dayChange: 0),
            funded.info.metaId: balance(total: 12, dayChange: -0.05)
        ]

        let cards = makeFactory().buildViewModel(viewType: .wallets, from: [missing, empty, funded], balances: balances, locale: locale)

        XCTAssertEqual(cards.map(\.walletName), [missing, empty, funded].map(\.info.name))
        XCTAssertEqual(cards.map(\.isSelected), [true, false, false])
        XCTAssertNil(cards[0].fiatBalance)
        XCTAssertNil(cards[0].dayChange)
        XCTAssertEqual(cards[1].fiatBalance, fiat(0))
        XCTAssertNil(cards[1].dayChange)
        XCTAssertEqual(cards[2].fiatBalance, fiat(12))
        let dayChange = try XCTUnwrap(cards[2].dayChange?.string)
        XCTAssertTrue(dayChange.hasSuffix("(\(try XCTUnwrap(fiat(0.6))))"))
        XCTAssertNil(cards[2].balanceCaption)
    }

    func testWalletPickerMarksOnlyThePreviouslyChosenWallet() {
        let first = ManagedMetaAccountModel(info: AccountGenerator.generateMetaAccount(), isSelected: true)
        let second = ManagedMetaAccountModel(info: AccountGenerator.generateMetaAccount())
        let factory = makeFactory()

        let chosen = factory.buildViewModel(
            viewType: .selectYourWallet(selectedWalletId: second.info.metaId),
            from: [first, second],
            balances: [:],
            locale: locale
        )
        let none = factory.buildViewModel(viewType: .selectYourWallet(selectedWalletId: nil), from: [first, second], balances: [:], locale: locale)

        XCTAssertEqual(chosen.map(\.isSelected), [false, true])
        XCTAssertEqual(none.map(\.isSelected), [false, false])
    }

    private func makeFactory() -> WalletsManagmentViewModelFactory {
        WalletsManagmentViewModelFactory(assetBalanceFormatterFactory: AssetBalanceFormatterFactory())
    }

    private func fiat(_ value: Decimal) -> String? {
        AssetBalanceFormatterFactory()
            .createTokenFormatter(for: AssetBalanceDisplayInfo.forCurrency(currency), usageCase: .fiat)
            .value(for: locale)
            .stringFromDecimal(value)
    }

    private func balance(total: Decimal, dayChange: Decimal) -> WalletBalanceInfo {
        WalletBalanceInfo(
            totalFiatValue: total,
            enabledAssetFiatBalance: total,
            dayChangePercent: dayChange,
            dayChangeValue: total * dayChange,
            totalDayChangePercent: dayChange,
            totalDayChangeValue: total * dayChange,
            currency: currency,
            prices: [],
            accountInfos: [:],
            exclusions: PortfolioExclusions()
        )
    }
}

final class CovJMxWalletsCellDelegate: WalletsManagmentTableCellDelegate {
    var options: [IndexPath?] = []
    func didTapOptionsCell(with indexPath: IndexPath?) { options.append(indexPath) }
}

final class CovJMxWalletsCellTests: XCTestCase {
    func testCellHidesBalancesBehindASkeletonUntilTheyArriveAndForwardsTaps() throws {
        let cell = WalletsManagmentTableCell(style: .default, reuseIdentifier: nil)
        cell.frame = CGRect(x: 0, y: 0, width: 390, height: 72)
        let delegate = CovJMxWalletsCellDelegate()
        cell.delegate = delegate
        let change = NSAttributedString(string: "+1.00% ($0.10)")

        cell.bind(to: WalletsManagmentCellViewModel(isSelected: true, walletName: "Main", fiatBalance: nil, dayChange: change))

        let labels = CovJViewFixture.descendants(UILabel.self, in: cell)
        let dayChange = try XCTUnwrap(labels.first { $0.attributedText?.string == change.string })
        XCTAssertEqual(dayChange.alpha, 0)
        XCTAssertTrue(labels.contains { $0.text == "Main" })
        cell.didAppearSkeleton()
        cell.didDisappearSkeleton()
        cell.frame = CGRect(x: 0, y: 0, width: 320, height: 72)
        cell.didUpdateSkeletonLayout()
        XCTAssertEqual(dayChange.alpha, 0)

        cell.bind(to: WalletsManagmentCellViewModel(
            isSelected: false, walletName: "Main", fiatBalance: "$5.00", dayChange: change
        ))
        XCTAssertEqual(dayChange.alpha, 1)
        XCTAssertTrue(labels.contains { $0.text == "$5.00" && $0.alpha == 1 })
        cell.didUpdateSkeletonLayout()
        cell.prepareForReuse()

        let options = try XCTUnwrap(CovJViewFixture.descendants(UIButton.self, in: cell).first { !$0.isHidden && $0.allTargets.contains(cell) })
        options.sendActions(for: .touchUpInside)
        XCTAssertEqual(delegate.options.count, 1)
        XCTAssertNil(delegate.options.first ?? nil)
    }
}
