@testable import fearless
import SoraFoundation
import SoraUI
import SSFModels
import UIKit
import XCTest

/// Modal pickers built by `ModalPickerFactory`, `ModalInfoFactory` and `ModalAlertFactory`: titles, rows bound
/// into their cells, selection marks and the delegate/callback/presenter calls on selection.
@MainActor
final class CovEModalPickerTests: XCTestCase {
    private var locale: Locale {
        LocalizationManager.shared.selectedLocale
    }

    func testCryptoTypePickerBindsRowsMarksSelectionAndNotifiesDelegate() throws {
        XCTAssertNil(ModalPickerFactory.createPickerForList([CryptoType](), selectedType: nil, delegate: nil, context: nil))
        let delegate = CovEPickerDelegate()
        let context = NSString(string: "crypto")
        let types: [CryptoType] = [.sr25519, .ed25519, .ecdsa]
        let picker = try XCTUnwrap(
            ModalPickerFactory.createPickerForList(types, selectedType: .ed25519, delegate: delegate, context: context)
                as? ModalPickerViewController<TitleWithSubtitleTableViewCell, TitleWithSubtitleViewModel>
        )
        XCTAssertEqual(picker.selectedIndex, 1)
        XCTAssertEqual(picker.preferredContentSize.height, picker.headerHeight + 3 * picker.cellHeight + picker.footerHeight)
        XCTAssertEqual(picker.localizedTitle?.value(for: locale), R.string.localizable.commonCryptoType(preferredLanguages: locale.rLanguages))
        let presenter = CovEModalPresenter()
        picker.presenter = presenter
        picker.icon = R.image.iconClose()
        picker.actionType = .add
        picker.hasCloseItem = true
        picker.separatorColor = .red
        let hosted = drive(picker)
        defer { CovEHost.close(hosted.window) }

        XCTAssertEqual(hosted.cells.count, 3)
        XCTAssertEqual(hosted.cells.map(\.checkmarked), [false, true, false])
        XCTAssertTrue(CovEFind.texts(in: hosted.cells[0]).contains(CryptoType.sr25519.titleForLocale(locale)))
        XCTAssertTrue(CovEFind.texts(in: hosted.cells[2]).contains(CryptoType.ecdsa.subtitleForLocale(locale)))
        XCTAssertEqual(picker.tableView(hosted.table, heightForRowAt: IndexPath(row: 0, section: 0)), picker.cellHeight)
        XCTAssertEqual(hosted.table.separatorColor, .red)

        picker.tableView(hosted.table, didSelectRowAt: IndexPath(row: 2, section: 0))
        XCTAssertEqual(picker.selectedIndex, 2)
        XCTAssertEqual(delegate.selected.map(\.0), [2])
        XCTAssertTrue(delegate.selected.first?.1 === context)
        XCTAssertEqual(presenter.hidden, 1, "Pickers hide after a selection by default")

        let buttons = CovEFind.all(RoundedButton.self, in: picker.view)
        XCTAssertEqual(buttons.count, 2, "Add and close buttons are installed in the header")
        let addButton = try XCTUnwrap(buttons.first { $0.imageWithTitleView?.iconImage == R.image.iconSmallAdd() })
        let closeButton = try XCTUnwrap(buttons.first { $0.imageWithTitleView?.iconImage == R.image.iconClose() })
        addButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(delegate.actions, 1)
        XCTAssertEqual(presenter.hidden, 2)
        closeButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(presenter.hidden, 3)

        picker.presenterDidHide(presenter)
        XCTAssertEqual(delegate.cancels, 1)
        XCTAssertTrue(picker.presenterCanDrag(presenter))
        picker.presenterCanDrag = false
        XCTAssertFalse(picker.presenterCanDrag(presenter))
        picker.applyLocalization()
        XCTAssertEqual(picker.tableView(hosted.table, numberOfRowsInSection: 0), 3)

        let unselected = try XCTUnwrap(
            ModalPickerFactory.createPickerForList(types, selectedType: nil, delegate: nil, context: nil)
                as? ModalPickerViewController<TitleWithSubtitleTableViewCell, TitleWithSubtitleViewModel>
        )
        XCTAssertEqual(unselected.selectedIndex, 0)
    }

    func testImportSourcePickerAndUnloadedLocalizationAreSafe() throws {
        XCTAssertNil(ModalPickerFactory.createPickerForList([AccountImportSource](), selectedType: nil, delegate: nil, context: nil))
        let sources = AccountImportSource.allCases
        let picker = try XCTUnwrap(
            ModalPickerFactory.createPickerForList(sources, selectedType: .seed, delegate: nil, context: nil)
                as? ModalPickerViewController<TitleWithSubtitleTableViewCell, TitleWithSubtitleViewModel>
        )
        picker.applyLocalization()
        XCTAssertFalse(picker.isViewLoaded, "Localization does not force the view to load")
        XCTAssertEqual(picker.selectedIndex, sources.firstIndex(of: .seed))
        let hosted = drive(picker)
        defer { CovEHost.close(hosted.window) }
        XCTAssertEqual(hosted.cells.count, sources.count)
        XCTAssertEqual(hosted.cells.filter(\.checkmarked).count, 1)
        XCTAssertTrue(hosted.cells.allSatisfy { !CovEFind.texts(in: $0).isEmpty })

        let none = try XCTUnwrap(
            ModalPickerFactory.createPickerForList(sources, selectedType: nil, delegate: nil, context: nil)
                as? ModalPickerViewController<TitleWithSubtitleTableViewCell, TitleWithSubtitleViewModel>
        )
        XCTAssertEqual(none.selectedIndex, 0)
    }

    func testAccountPickerGeneratesIconsAndKeepsNoSelectionWhenAccountIsMissing() throws {
        let first = account(name: "Main", seed: 1)
        let second = account(name: "Savings", seed: 2)
        let title = LocalizableResource { _ in "Accounts" }
        let delegate = CovEPickerDelegate()
        let picker = try XCTUnwrap(
            ModalPickerFactory.createPickerList([first, second], selectedAccount: second, title: title, delegate: delegate, context: nil)
                as? ModalPickerViewController<AccountPickerTableViewCell, AccountPickerViewModel>
        )
        XCTAssertEqual(picker.selectedIndex, 1)
        XCTAssertEqual(picker.viewModels.map { $0.value(for: locale).title }, ["Main", "Savings"])
        let hosted = drive(picker)
        defer { CovEHost.close(hosted.window) }
        XCTAssertEqual(hosted.cells.map(\.checkmarked), [false, true])
        XCTAssertTrue(CovEFind.texts(in: hosted.cells[0]).contains("Main"))
        picker.tableView(hosted.table, didSelectRowAt: IndexPath(row: 0, section: 0))
        XCTAssertEqual(delegate.selected.map(\.0), [0])

        let unselected = try XCTUnwrap(
            ModalPickerFactory.createPickerList([first], selectedAccount: nil, title: title, delegate: nil, context: nil)
                as? ModalPickerViewController<AccountPickerTableViewCell, AccountPickerViewModel>
        )
        XCTAssertEqual(unselected.selectedIndex, NSNotFound)
    }

    func testStakingManagePurchaseAndTotalStakePickers() throws {
        XCTAssertNil(ModalPickerFactory.createPickerForList([StakingManageOption](), delegate: nil, context: nil))
        let options: [StakingManageOption] = [.stakingBalance, .pendingRewards, .changeValidators(count: 3), .yourValidator]
        let manage = try XCTUnwrap(
            ModalPickerFactory.createPickerForList(options, delegate: nil, context: nil)
                as? ModalPickerViewController<StakingManageCell, StakingManageViewModel>
        )
        XCTAssertEqual(manage.selectedIndex, NSNotFound)
        XCTAssertEqual(manage.separatorStyle, .singleLine)
        XCTAssertEqual(manage.cellHeight, StakingManageCell.cellHeight)
        XCTAssertEqual(manage.viewModels.map { $0.value(for: locale).title }, options.map { $0.titleForLocale(locale) })
        let manageHosted = drive(manage)
        CovEHost.close(manageHosted.window)
        XCTAssertEqual(manageHosted.cells.count, 4)

        XCTAssertNil(ModalPickerFactory.createPickerForList([PurchaseAction](), delegate: nil, context: nil))
        let url = try XCTUnwrap(URL(string: "https://example.invalid/buy"))
        let purchase = try XCTUnwrap(
            try ModalPickerFactory.createPickerForList(
                [PurchaseAction(title: "Ramp", url: url, icon: XCTUnwrap(R.image.iconClose()))], delegate: nil, context: nil
            ) as? ModalPickerViewController<PurchaseProviderPickerTableViewCell, IconWithTitleViewModel>
        )
        let purchaseHosted = drive(purchase)
        CovEHost.close(purchaseHosted.window)
        XCTAssertTrue(CovEFind.texts(in: purchaseHosted.cells[0]).contains("Ramp"))
        XCTAssertFalse(purchaseHosted.cells[0].checkmarked)

        XCTAssertNil(ModalPickerFactory.createPickerForList([LocalizableResource<StakingAmountViewModel>](), delegate: nil, context: nil))
        let stakes = [
            LocalizableResource { _ in StakingAmountViewModel(title: "Own", balance: BalanceViewModel(amount: "10 DOT", price: "$50")) },
            LocalizableResource { _ in StakingAmountViewModel(title: "Nominators", balance: BalanceViewModel(amount: "2 DOT", price: nil)) }
        ]
        let total = try XCTUnwrap(
            ModalPickerFactory.createPickerForList(stakes, delegate: nil, context: nil)
                as? ModalPickerViewController<BottomSheetInfoBalanceCell, StakingAmountViewModel>
        )
        XCTAssertEqual(total.separatorColor, R.color.colorDarkGray())
        let totalHosted = drive(total)
        CovEHost.close(totalHosted.window)
        XCTAssertEqual(totalHosted.cells[0].amountLabel.text, "10 DOT")
        XCTAssertEqual(totalHosted.cells[0].priceLabel.text, "$50")
        XCTAssertEqual(totalHosted.cells[1].priceLabel.text, "", "A missing price renders as an empty label")
        XCTAssertEqual(totalHosted.cells[1].titleLabel.text, "Nominators")
    }

    func testChainActionJsonExportAndReplacePickersCallBack() throws {
        XCTAssertNil(ModalPickerFactory.createPickerForList(title: "x", [ChainAction](), callback: nil, context: nil))
        var picked: [Int] = []
        let actions: [ChainAction] = [.copyAddress, .switchNode, .export, .replace]
        let chain = try XCTUnwrap(
            ModalPickerFactory.createPickerForList(title: "Polkadot", actions, callback: { picked.append($0) }, context: nil)
                as? ModalPickerViewController<IconWithTitleTableViewCell, IconWithTitleViewModel>
        )
        XCTAssertEqual(chain.localizedTitle?.value(for: locale), "Polkadot")
        XCTAssertFalse(chain.showSelection)
        let chainHosted = drive(chain)
        defer { CovEHost.close(chainHosted.window) }
        XCTAssertTrue(chainHosted.cells.allSatisfy { !$0.checkmarked }, "Action lists never show a check mark")
        XCTAssertTrue(CovEFind.texts(in: chainHosted.cells[0]).contains(ChainAction.copyAddress.localizableTitle(for: locale)))
        chain.tableView(chainHosted.table, didSelectRowAt: IndexPath(row: 3, section: 0))
        XCTAssertEqual(picked, [3])

        XCTAssertNil(ModalPickerFactory.createPickerForList([JsonExportAction](), callback: nil, context: nil))
        let json = try XCTUnwrap(
            ModalPickerFactory.createPickerForList([JsonExportAction.file, .text], callback: { picked.append($0 + 10) }, context: nil)
                as? ModalPickerViewController<TitleWithSubtitleTableViewCell, TitleWithSubtitleViewModel>
        )
        XCTAssertEqual(json.viewModels.map { $0.value(for: locale).title }, [
            JsonExportAction.file.localizableTitle(for: locale), JsonExportAction.text.localizableTitle(for: locale)
        ])
        let jsonHosted = drive(json)
        CovEHost.close(jsonHosted.window)
        json.tableView(jsonHosted.table, didSelectRowAt: IndexPath(row: 1, section: 0))
        XCTAssertEqual(picked, [3, 11])

        XCTAssertNil(ModalPickerFactory.createPickerForList([ReplaceChainOption](), callback: nil, context: nil))
        let replace = try XCTUnwrap(
            ModalPickerFactory.createPickerForList(ReplaceChainOption.allCases, callback: { picked.append($0 + 20) }, context: nil)
                as? ModalPickerViewController<IconWithTitleTableViewCell, IconWithTitleViewModel>
        )
        XCTAssertEqual(replace.viewModels.map { $0.value(for: locale).icon }, ReplaceChainOption.allCases.map(\.icon))
        let replaceHosted = drive(replace)
        CovEHost.close(replaceHosted.window)
        replace.tableView(replaceHosted.table, didSelectRowAt: IndexPath(row: 0, section: 0))
        XCTAssertEqual(picked, [3, 11, 20])
    }

    func testCurrencyFilterSortAndOptionsPickers() throws {
        let usd = Currency(id: "usd", symbol: "$", name: "US Dollar", icon: "", isSelected: false)
        let eur = Currency(id: "eur", symbol: "€", name: "Euro", icon: "https://example.invalid/eur.png", isSelected: true)
        var picked: [Int] = []
        let currency = try XCTUnwrap(
            ModalPickerFactory.createPickerForSelectCurrency(supportedСurrencies: [usd, eur], selectedCurrency: eur, callback: { picked.append($0) })
                as? ModalPickerViewController<IconWithTitleTableViewCell, IconWithTitleViewModel>
        )
        XCTAssertEqual(currency.selectedIndex, 1)
        XCTAssertFalse(currency.presenterCanDrag)
        let models = currency.viewModels.map { $0.value(for: locale) }
        XCTAssertEqual(models.map(\.title), ["USD", "EUR"])
        XCTAssertNil(models[0].remoteImageViewModel, "An empty icon string has no remote image")
        XCTAssertNotNil(models[1].remoteImageViewModel)
        let currencyHosted = drive(currency)
        CovEHost.close(currencyHosted.window)
        XCTAssertEqual(currencyHosted.cells.map(\.checkmarked), [false, true])
        let unknown = Currency(id: "jpy", symbol: "¥", name: "Yen", icon: "", isSelected: false)
        let fallback = try XCTUnwrap(
            ModalPickerFactory.createPickerForSelectCurrency(supportedСurrencies: [usd], selectedCurrency: unknown, callback: nil)
                as? ModalPickerViewController<IconWithTitleTableViewCell, IconWithTitleViewModel>
        )
        XCTAssertEqual(fallback.selectedIndex, 0)

        let filters = [
            TitleSwitchTableViewCellModel(icon: R.image.iconClose(), title: "Hide zero", switchIsOn: true),
            TitleSwitchTableViewCellModel(icon: nil, title: "Testnets", switchIsOn: false)
        ]
        let filter = try XCTUnwrap(
            ModalPickerFactory.createPickerForFilterOptions(options: filters)
                as? ModalPickerViewController<TitleSwitchTableViewCell, TitleSwitchTableViewCellModel>
        )
        XCTAssertFalse(filter.hideWhenDidSelected)
        let filterHosted = drive(filter)
        CovEHost.close(filterHosted.window)
        let switches = filterHosted.cells.compactMap { CovEFind.first(UISwitch.self, in: $0) }
        XCTAssertEqual(switches.map(\.isOn), [true, false])
        XCTAssertTrue(CovEFind.texts(in: filterHosted.cells[1]).contains("Testnets"))
        switches[1].isOn = true
        switches[1].sendActions(for: .valueChanged)
        XCTAssertEqual(filterHosted.cells[0].selectionStyle, .none)

        let sortings = TitleSwitchTableViewCellModelFactory().createSortings(
            options: [.numberOfMembers, .totalStake(assetSymbol: "DOT")], selectedOption: .numberOfMembers, locale: locale
        )
        XCTAssertEqual(sortings.map(\.switchIsOn), [true, false])
        XCTAssertEqual(sortings.map(\.sortOption), [.numberOfMembers, .totalStake(assetSymbol: "DOT")])
        XCTAssertTrue(sortings[1].title.contains("DOT"))
        let sort = try XCTUnwrap(
            ModalPickerFactory.createPickerForSortOptions(options: sortings, callback: { picked.append($0 + 100) })
                as? ModalPickerViewController<SortPickerTableViewCell, SortPickerTableViewCellModel>
        )
        let sortHosted = drive(sort)
        CovEHost.close(sortHosted.window)
        let icons = sortHosted.cells.compactMap { CovEFind.first(UIImageView.self, in: $0.contentView) }
        XCTAssertEqual(icons.first?.image, R.image.iconListSelectionOn())
        XCTAssertNil(icons.last?.image, "Only the chosen sorting shows the selection icon")
        sort.tableView(sortHosted.table, didSelectRowAt: IndexPath(row: 1, section: 0))
        XCTAssertEqual(picked, [101])

        let options = try XCTUnwrap(
            ModalPickerFactory.createPicker(
                viewModels: [TitleWithSubtitleViewModel(title: "Rename", subtitle: "Edit name")],
                callback: { picked.append($0 + 1000) }
            ) as? ModalPickerViewController<TitleWithSubtitleTableViewCell, TitleWithSubtitleViewModel>
        )
        XCTAssertEqual(options.headerBorderType, .none)
        let optionsHosted = drive(options)
        CovEHost.close(optionsHosted.window)
        XCTAssertTrue(CovEFind.texts(in: optionsHosted.cells[0]).contains("Edit name"))
        options.tableView(optionsHosted.table, didSelectRowAt: IndexPath(row: 0, section: 0))
        XCTAssertEqual(picked, [101, 1000])
    }

    func testRewardInfoAndSuccessAlertControllers() throws {
        let info = try XCTUnwrap(
            ModalInfoFactory.createRewardDetails(for: (title: "Max", amount: 0.2), avgReward: (title: "Average", amount: 0.15))
                as? ModalPickerViewController<DetailsDisplayTableViewCell, TitleWithSubtitleViewModel>
        )
        XCTAssertFalse(info.allowsSelection)
        XCTAssertEqual(info.preferredContentSize.height, ModalInfoFactory.headerHeight + 2 * ModalInfoFactory.rowHeight)
        let rows = info.viewModels.map { $0.value(for: locale) }
        XCTAssertEqual(rows.map(\.title), ["Max", "Average"])
        XCTAssertTrue(rows[0].subtitle.contains("20"))
        XCTAssertTrue(rows[1].subtitle.contains("15"))
        let hosted = drive(info)
        CovEHost.close(hosted.window)
        XCTAssertFalse(hosted.table.allowsSelection)
        XCTAssertTrue(CovEFind.texts(in: hosted.cells[1]).contains("Average"))

        let success = ModalAlertFactory.createSuccessAlert("Copied")
        let content = try XCTUnwrap(success.view as? ImageWithTitleView)
        XCTAssertEqual(content.title, "Copied")
        XCTAssertEqual(content.layoutType, .verticalImageFirst)
        XCTAssertEqual(success.modalPresentationStyle, .custom)
        XCTAssertNotNil(success.modalTransitioningFactory)

        let multiline = ModalAlertFactory.createMultilineSuccessAlert("Address copied to clipboard", dissmisAfter: 1)
        let alertView = try XCTUnwrap(multiline.view as? AlertImageWithTitleView)
        XCTAssertEqual(alertView.titleLabel.text, "Address copied to clipboard")
        XCTAssertEqual(alertView.titleLabel.textAlignment, .center)
        XCTAssertEqual(alertView.imageView.image, R.image.iconValidBig())
        XCTAssertGreaterThan(alertView.intrinsicContentSize.height, 32)
        XCTAssertEqual(multiline.modalPresentationStyle, .custom)
    }

    // MARK: - Helpers

    private func drive<C: UITableViewCell & ModalPickerCellProtocol, T>(
        _ picker: ModalPickerViewController<C, T>
    ) -> (window: UIWindow, table: UITableView, cells: [C]) {
        let window = CovEHost.window(for: picker)
        let table = CovEFind.first(UITableView.self, in: picker.view) ?? UITableView()
        table.reloadData()
        table.layoutIfNeeded()
        let count = picker.tableView(table, numberOfRowsInSection: 0)
        let cells = (0 ..< count).compactMap {
            picker.tableView(table, cellForRowAt: IndexPath(row: $0, section: 0)) as? C
        }
        return (window, table, cells)
    }

    private func account(name: String, seed: UInt8) -> ChainAccountResponse {
        ChainAccountResponse(
            chainId: "covE-chain", accountId: Data(repeating: seed, count: 32), publicKey: Data(repeating: seed, count: 32),
            name: name, cryptoType: .sr25519, addressPrefix: 0,
            isEthereumBased: false, isChainAccount: false, walletId: "covE-wallet"
        )
    }
}

final class CovEPickerDelegate: ModalPickerViewControllerDelegate {
    private(set) var selected: [(Int, AnyObject?)] = []
    private(set) var cancels = 0
    private(set) var actions = 0

    func modalPickerDidSelectModelAtIndex(_ index: Int, context: AnyObject?) {
        selected.append((index, context))
    }

    func modalPickerDidCancel(context _: AnyObject?) {
        cancels += 1
    }

    func modalPickerDidSelectAction(context _: AnyObject?) {
        actions += 1
    }
}

final class CovEModalPresenter: ModalPresenterProtocol {
    private(set) var hidden = 0

    func hide(view _: ModalViewProtocol, animated _: Bool) {
        hidden += 1
    }
}
