@testable import fearless
import Rswift
import SoraUI
import UIKit
import XCTest

/// Swipeable cells, the status banner window, amount input v2, rows, switches and the selection list.
@MainActor
final class CovEInteractiveViewsTests: XCTestCase {
    func testSwipableCellOpensMenusFromPansAndForwardsButtonTaps() throws {
        let cell = SwipableTableViewCell(style: .default, reuseIdentifier: nil)
        let send = VerticalContentButton.createSendButton(locale: Locale(identifier: "en"))
        let hide = VerticalContentButton.createHideButton(locale: nil)
        let receive = VerticalContentButton.createReceiveButton(locale: nil)
        XCTAssertEqual(
            [send, hide, receive, VerticalContentButton.createTeleportButton(locale: nil), VerticalContentButton.createShowButton(locale: nil)].map(\.type),
            [.send, .hide, .receive, .teleport, .show]
        )
        XCTAssertEqual(send.tag, SwipableCellButtonType.send.rawValue)
        XCTAssertEqual(send.title(for: .normal), R.string.localizable.commonActionSend(preferredLanguages: ["en"]))
        cell.rightMenuButtons = [send, hide]
        cell.leftMenuButtons = [receive]
        let delegate = CovESwipeDelegate()
        cell.delegate = delegate
        let hosted = host(cell)
        defer { CovEHost.close(hosted.window) }
        let inset = cell.cloudViewEdgeInsets.left
        XCTAssertEqual(cell.cloudView.frame.minX, inset)
        XCTAssertEqual(cell.openMenuTrigger, cell.actionButtonWidht * 0.7)
        XCTAssertEqual(cell.closeSwipeAnimationDuration, 0.3)

        let pan = CovEPan()
        swipe(cell, pan, .began, x: 300, velocity: -100)
        swipe(cell, pan, .changed, x: 200, velocity: -100)
        XCTAssertLessThan(cell.cloudView.frame.minX, inset, "The content follows a leftward drag")
        swipe(cell, pan, .ended, x: 100, velocity: -100)
        cell.layoutIfNeeded()
        XCTAssertEqual(cell.cloudView.frame.minX, -2 * cell.actionButtonWidht, accuracy: 0.5, "A long drag opens the right menu")

        hide.sendActions(for: .touchUpInside)
        XCTAssertEqual(delegate.taps.map(\.0), [.hide])
        XCTAssertEqual(delegate.taps.first?.1, IndexPath(row: 0, section: 0))
        cell.layoutIfNeeded()
        XCTAssertEqual(cell.cloudView.frame.minX, inset, "A button tap closes the menu")

        swipe(cell, pan, .began, x: 50, velocity: 100)
        swipe(cell, pan, .changed, x: 120, velocity: 100)
        swipe(cell, pan, .ended, x: 200, velocity: 100)
        cell.layoutIfNeeded()
        XCTAssertGreaterThan(cell.cloudView.frame.minX, inset, "A rightward drag opens the left menu")
        swipe(cell, pan, .began, x: 200, velocity: -100)
        swipe(cell, pan, .changed, x: 150, velocity: -100)
        swipe(cell, pan, .ended, x: 190, velocity: -100)
        cell.layoutIfNeeded()
        XCTAssertEqual(cell.cloudView.frame.minX, inset, "A short drag back closes the left menu")

        swipe(cell, pan, .began, x: 200, velocity: -100)
        swipe(cell, pan, .ended, x: 195, velocity: -100)
        cell.layoutIfNeeded()
        XCTAssertEqual(cell.cloudView.frame.minX, inset, "A short drag does not open a menu")

        let cellPan = try XCTUnwrap(cell.cloudView.gestureRecognizers?.first as? UIPanGestureRecognizer)
        XCTAssertTrue(cell.gestureRecognizer(cellPan, shouldRecognizeSimultaneouslyWith: UITapGestureRecognizer()))
        XCTAssertTrue(cell.gestureRecognizer(UITapGestureRecognizer(), shouldRecognizeSimultaneouslyWith: hosted.table.panGestureRecognizer))
        _ = cell.gestureRecognizerShouldBegin(cellPan)
        _ = cell.gestureRecognizerShouldBegin(UITapGestureRecognizer())
        cell.rightMenuButtons = []
        cell.leftMenuButtons = []
        XCTAssertFalse(cell.gestureRecognizerShouldBegin(cellPan), "A cell without menus never starts a swipe")
        swipe(cell, pan, .ended, x: 0, velocity: 0)
        cell.prepareForReuse()
        cell.layoutIfNeeded()
        XCTAssertEqual(cell.cloudView.frame.minX, inset)
    }

    func testFearlessWindowPresentsChangesAndDismissesTheStatusBanner() throws {
        let window = FearlessWindow(frame: CGRect(origin: .zero, size: CovEHost.phoneSize))
        window.windowScene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        window.rootViewController = UIViewController()
        window.isHidden = false
        defer { CovEHost.close(window) }
        window.layoutIfNeeded()
        XCTAssertNil(window.lastTouchedView)
        let locale = Locale(identifier: "en")
        window.presentStatus(with: ConnectionOfflineEvent(locale: locale), animated: false)
        let banner = try XCTUnwrap(window.subviews.compactMap { $0 as? ApplicationStatusView }.first)
        banner.layoutIfNeeded()
        XCTAssertTrue(CovEFind.texts(in: banner).contains(ConnectionOfflineEvent(locale: locale).titleText))
        XCTAssertEqual(banner.fillColor, ConnectionOfflineEvent(locale: locale).backgroundColor)

        window.addSubview(UIView())
        XCTAssertTrue(window.subviews.last === banner, "The banner stays above views added later")
        let other = UIView()
        window.addSubview(other)
        window.bringSubviewToFront(other)
        XCTAssertTrue(window.subviews.last === banner)

        window.presentStatus(with: ConnectionOnlineEvent(locale: locale), animated: false)
        XCTAssertEqual(banner.fillColor, ConnectionOnlineEvent(locale: locale).backgroundColor, "A second event rebinds the same banner")
        window.presentStatus(with: CommonCopiedEvent(locale: locale), animated: true)
        CovEHost.spin(0.3)
        XCTAssertEqual(banner.fillColor, CommonCopiedEvent(locale: locale).backgroundColor)
        window.dismissStatus(with: nil, animated: false)
        XCTAssertNil(banner.superview)
        window.dismissStatus(with: nil, animated: false)

        window.presentStatus(with: ConnectionOfflineEvent(locale: locale), animated: true)
        let second = try XCTUnwrap(window.subviews.compactMap { $0 as? ApplicationStatusView }.first)
        window.dismissStatus(with: AddressCopiedEvent(locale: locale), animated: true)
        CovEHost.spin(0.3)
        XCTAssertEqual(second.fillColor, AddressCopiedEvent(locale: locale).backgroundColor)

        let events: [ApplicationStatusAlertEvent] = [
            HashCopiedEvent(locale: locale), AddressCopiedEvent(locale: locale), CommonCopiedEvent(locale: nil),
            ConnectionOnlineEvent(locale: locale), ConnectionOfflineEvent(locale: nil)
        ]
        XCTAssertEqual(events.map(\.autoDismissing), [true, true, true, true, false])
        XCTAssertTrue(events.allSatisfy { !$0.titleText.isEmpty })
    }

    func testAmountInputViewV2BindsBalanceKindsAndFocusesOnTap() throws {
        let icon = BundleImageViewModel(image: R.image.iconClose())
        let model = AssetBalanceViewModel(symbol: "dot", balance: "10", fiatBalance: "$50", price: "$5", iconViewModel: icon, selectable: true)
        let locale = Locale(identifier: "en")
        let expectations: [(AmountInputViewV2Type, String)] = [
            (.balance, R.string.localizable.commonBalanceFormat("10", preferredLanguages: locale.rLanguages)),
            (.available, R.string.localizable.commonAvailableFormat("10", preferredLanguages: locale.rLanguages)),
            (.bonded, R.string.localizable.stakingBondedFormat("10", preferredLanguages: locale.rLanguages))
        ]
        for (type, text) in expectations {
            let view = AmountInputViewV2(type: type)
            view.locale = locale
            view.bind(viewModel: model)
            XCTAssertEqual(view.balanceText, text)
            XCTAssertEqual(view.symbol, "DOT")
            XCTAssertEqual(view.priceText, "$5")
            XCTAssertFalse(view.iconView.isHidden)
            XCTAssertEqual(view.iconView.image, R.image.iconClose())
            XCTAssertEqual(view.title, R.string.localizable.walletSendAmountTitle(preferredLanguages: locale.rLanguages))
        }
        let view = AmountInputViewV2()
        view.bind(viewModel: AssetBalanceViewModel(symbol: "ksm", balance: nil, fiatBalance: nil, price: nil, iconViewModel: nil, selectable: false))
        XCTAssertNil(view.balanceText)
        XCTAssertTrue(view.iconView.isHidden)
        view.title = "Amount"
        view.priceText = "$1"
        view.balanceText = "Balance: 1"
        view.symbol = "KSM"
        view.inputFieldText = "0.5"
        XCTAssertEqual([view.title, view.priceText, view.balanceText, view.symbol, view.inputFieldText], ["Amount", "$1", "Balance: 1", "KSM", "0.5"])
        XCTAssertEqual(view.textField.text, "0.5")
        view.set(highlighted: true, animated: false)
        let window = CovEHost.window(for: view, frame: CGRect(x: 16, y: 100, width: 358, height: 96))
        defer { CovEHost.close(window) }
        window.makeKeyAndVisible()
        let tap = try XCTUnwrap(view.gestureRecognizers?.first)
        view.perform(NSSelectorFromString("handleTapGesture"), with: tap)
        XCTAssertTrue(view.textField.isFirstResponder)
        view.perform(NSSelectorFromString("handleTapGesture"), with: tap)
        XCTAssertTrue(view.textField.isFirstResponder)
        view.textField.resignFirstResponder()
    }

    func testRowIconDetailsAndSlippageViews() {
        let label = UILabel()
        label.text = "Row content"
        label.numberOfLines = 0
        let row = RowView(contentView: label)
        XCTAssertTrue(row.rowContentView === label)
        let window = CovEHost.window(for: row, frame: CGRect(x: 0, y: 100, width: 390, height: 60))
        defer { CovEHost.close(window) }
        XCTAssertGreaterThan(row.intrinsicContentSize.height, 0)
        XCTAssertEqual(label.frame.minX, UIConstants.horizontalInset)
        XCTAssertEqual(row.borderView.frame.height, 60)
        row.preferredHeight = 80
        row.frame.size.height = 80
        row.layoutIfNeeded()
        XCTAssertEqual(row.intrinsicContentSize.height, 80)
        XCTAssertEqual(label.frame.height, 80)
        let generic = RowView<UIView>(frame: .zero)
        XCTAssertNotNil(generic.rowContentView)
        XCTAssertNotNil(generic.backgroundView as? ShapeView)

        let details = IconDetailsView()
        details.detailsLabel.text = "Details"
        details.imageView.image = R.image.iconInfoFilled()
        let stack = CovEFind.first(UIStackView.self, in: details)
        XCTAssertEqual(stack?.arrangedSubviews.first, details.imageView)
        details.mode = .detailsIcon
        XCTAssertEqual(stack?.arrangedSubviews.first, details.detailsLabel)
        details.spacing = 3
        XCTAssertEqual(details.spacing, 3)
        details.stackViewAlignment = .top
        XCTAssertEqual(stack?.alignment, .top)
        details.iconWidth = 24
        let second = CovEHost.window(for: details, frame: CGRect(x: 0, y: 200, width: 300, height: 30))
        defer { CovEHost.close(second) }
        XCTAssertEqual(details.imageView.frame.width, 24)
        details.prepareForInterfaceBuilder()
        XCTAssertEqual(stack?.arrangedSubviews.count, 2)

        let slippage = SlippageToleranceView()
        slippage.bind(with: SlippageToleranceViewModel(value: 0.5, textFieldText: "0.5", labelAttributedString: nil, image: nil))
        XCTAssertEqual(slippage.textField.text, "0.5")
        XCTAssertEqual(slippage.titleLabel.textColor, R.color.colorStrokeGray())
        slippage.bind(with: SlippageToleranceViewModel(
            value: 5, textFieldText: "5", labelAttributedString: NSAttributedString(string: "High"), image: R.image.iconWarning()
        ))
        XCTAssertEqual(slippage.titleLabel.textColor, R.color.colorOrange(), "Risky slippage is shown in orange")
        let warning = CovEFind.all(UIImageView.self, in: slippage).first { $0.image == R.image.iconWarning() }
        XCTAssertEqual(warning?.isHidden, false)
        slippage.set(highlighted: false, animated: false)
        let background = CovEFind.first(TriangularedView.self, in: slippage)
        XCTAssertEqual(background?.highlightedStrokeColor, R.color.colorPink())
    }

    func testSwitchCellsForwardTogglesAndBindSubtitles() {
        let cell = SwitchTableViewCell(style: .default, reuseIdentifier: nil)
        let delegate = CovESwitchDelegate()
        cell.delegate = delegate
        cell.bind(title: "Testnets", isOn: true)
        XCTAssertEqual(cell.titleLabel.text, "Testnets")
        XCTAssertTrue(cell.switchView.isOn)
        cell.switchView.sendActions(for: .valueChanged)
        XCTAssertEqual(delegate.toggles, 1)
        XCTAssertEqual(cell.selectionStyle, .none)

        let subtitled = TitleSubtitleSwitchTableViewCell(style: .default, reuseIdentifier: nil)
        subtitled.bind(viewModel: SelectableViewModel(
            underlyingViewModel: TitleWithSubtitleViewModel(title: "Hide zero", subtitle: "Balances"), selectable: true
        ))
        XCTAssertEqual(subtitled.titleLabel.text, "Hide zero")
        XCTAssertEqual(subtitled.subtitleLabel.text, "Balances")
        XCTAssertTrue(subtitled.switchView.isOn)
        XCTAssertEqual(subtitled.titleLabel.font, .h5Title)
        subtitled.frame = CGRect(x: 0, y: 0, width: 390, height: 64)
        subtitled.layoutIfNeeded()
        XCTAssertEqual(subtitled.stackView.arrangedSubviews, [subtitled.titleLabel, subtitled.subtitleLabel])
    }

    func testSelectionCellsFollowViewModelSelection() {
        let iconModel = SelectableIconDetailsListViewModel(title: "Polkadot", subtitle: "DOT", icon: nil, isSelected: false, identifier: "dot")
        let iconCell = SelectionIconDetailsTableViewCell(style: .default, reuseIdentifier: nil)
        iconCell.bind(viewModel: iconModel)
        XCTAssertEqual(iconCell.titleLabel.text, "Polkadot")
        XCTAssertEqual(iconCell.subtitleLabel.text, "DOT")
        XCTAssertEqual(iconCell.iconImageView.image, R.image.allNetworksIcon(), "A missing icon shows the all-networks icon")
        XCTAssertTrue(iconCell.checkmarkImageView.isHidden)
        iconModel.isSelected = true
        XCTAssertFalse(iconCell.checkmarkImageView.isHidden, "Selection changes reach bound cells")
        iconCell.prepareForReuse()
        iconModel.isSelected = false
        XCTAssertFalse(iconCell.checkmarkImageView.isHidden, "A reused cell stops observing")
        iconCell.bind(viewModel: SelectableIconDetailsListViewModel(
            title: "Kusama", subtitle: nil, icon: BundleImageViewModel(image: R.image.iconClose()), isSelected: true, identifier: nil
        ))
        XCTAssertEqual(iconCell.iconImageView.image, R.image.iconClose())
        iconCell.bind(viewModel: SelectableTitleListViewModel(title: "ignored"))
        XCTAssertEqual(iconCell.titleLabel.text, "Kusama", "Foreign view models are ignored")

        let expandable = ExpandableSubtitleCell(style: .default, reuseIdentifier: nil)
        let expandModel = SelectableSubtitleListViewModel(title: "Option", subtitle: "Explained", isSelected: false, isExpand: false)
        expandable.bind(viewModel: expandModel)
        XCTAssertTrue(expandable.subtitle.isHidden)
        XCTAssertEqual(expandable.infoButton.image(for: .normal), R.image.iconExpandable())
        expandModel.isExpand = true
        expandable.bind(viewModel: expandModel)
        XCTAssertFalse(expandable.subtitle.isHidden)
        XCTAssertEqual(expandable.infoButton.image(for: .normal), R.image.iconExpandableInverted())
        expandable.bind(viewModel: SelectableTitleListViewModel(title: "x"))
        XCTAssertEqual(expandable.titleLabel.text, "Option")
        let itemDelegate = CovESelectionItemDelegate()
        expandable.delegate = itemDelegate
        expandable.infoButton.sendActions(for: .touchUpInside)
        XCTAssertTrue(itemDelegate.taps.isEmpty, "A cell outside a table has no index path to report")

        let observer = CovESelectionObserver()
        let titleModel = SelectableTitleListViewModel(title: "English", isSelected: false)
        titleModel.addObserver(observer)
        titleModel.addObserver(observer)
        titleModel.isSelected = true
        titleModel.isSelected = true
        XCTAssertEqual(observer.changes, 1, "Observers are added once and told only about real changes")
        titleModel.removeObserver(observer)
        titleModel.isSelected = false
        XCTAssertEqual(observer.changes, 1)
    }

    func testSelectionListControllerShowsAndSelectsRows() throws {
        let presenter = CovESelectionPresenter(items: [
            SelectableTitleListViewModel(title: "English", isSelected: true),
            SelectableTitleListViewModel(title: "日本語")
        ])
        let controller = CovESelectionListController(nib: R.nib.selectionListViewController)
        controller.listPresenter = presenter
        let window = CovEHost.window(for: controller)
        defer { CovEHost.close(window) }
        controller.didReload()
        controller.tableView.layoutIfNeeded()
        XCTAssertEqual(controller.tableView(controller.tableView, numberOfRowsInSection: 0), 2)
        let first = try XCTUnwrap(controller.tableView(controller.tableView, cellForRowAt: IndexPath(row: 0, section: 0)) as? SelectionTitleTableViewCell)
        first.titleColor = .gray
        first.selectedTitleColor = .white
        first.checkmarkIcon = R.image.iconCheckMark()
        XCTAssertEqual(first.viewModel?.title, "English")
        XCTAssertEqual(CovEFind.texts(in: first), ["English"])
        XCTAssertEqual(CovEFind.label("English", in: first)?.textColor, .white)
        controller.tableView(controller.tableView, didSelectRowAt: IndexPath(row: 1, section: 0))
        XCTAssertEqual(presenter.selected, [1])
        controller.bind(viewModel: nil)
        controller.reloadCell(at: IndexPath(row: 0, section: 0))
        presenter.searchItem(with: "x")
        presenter.didTapAdditionalButton(at: IndexPath(row: 0, section: 0))
        XCTAssertNotNil(controller.tableView.tableFooterView)

        let subtitleCell = try XCTUnwrap(UINib(resource: R.nib.selectionSubtitleTableViewCell).instantiate(withOwner: nil).first as? SelectionSubtitleTableViewCell)
        let subtitleModel = SelectableSubtitleListViewModel(title: "Deutsch", subtitle: "German")
        subtitleCell.titleColor = .gray
        subtitleCell.selectedTitleColor = .white
        subtitleCell.subtitleColor = .darkGray
        subtitleCell.selectedSubtitleColor = .lightGray
        subtitleCell.checkmarkIcon = R.image.iconCheckMark()
        subtitleCell.bind(viewModel: subtitleModel)
        XCTAssertEqual(subtitleCell.viewModel?.subtitle, "German")
        XCTAssertEqual(CovEFind.label("German", in: subtitleCell)?.textColor, .darkGray)
        subtitleModel.isSelected = true
        XCTAssertEqual(CovEFind.label("German", in: subtitleCell)?.textColor, .lightGray)
        XCTAssertEqual(CovEFind.label("Deutsch", in: subtitleCell)?.textColor, .white)
        subtitleCell.prepareForReuse()
        subtitleCell.bind(viewModel: SelectableTitleListViewModel(title: "x"))
        XCTAssertEqual(subtitleCell.viewModel?.title, "Deutsch")
    }

    // MARK: - Helpers

    private func host(_ cell: UITableViewCell) -> (window: UIWindow, table: UITableView, source: CovETableSource) {
        let table = UITableView(frame: CGRect(origin: .zero, size: CovEHost.phoneSize))
        let source = CovETableSource(cells: [cell], height: 80)
        table.dataSource = source
        table.delegate = source
        let window = CovEHost.window(for: table, frame: CGRect(origin: .zero, size: CovEHost.phoneSize))
        table.reloadData()
        table.layoutIfNeeded()
        return (window, table, source)
    }

    private func swipe(_ cell: SwipableTableViewCell, _ pan: CovEPan, _ state: UIGestureRecognizer.State, x: CGFloat, velocity: CGFloat) {
        pan.stubState = state
        pan.stubLocation = CGPoint(x: x, y: 40)
        pan.stubVelocity = CGPoint(x: velocity, y: 0)
        cell.perform(NSSelectorFromString("panGestureWithGesture:"), with: pan)
    }
}

final class CovETableSource: NSObject, UITableViewDataSource, UITableViewDelegate {
    let cells: [UITableViewCell]
    let height: CGFloat

    init(cells: [UITableViewCell], height: CGFloat) {
        self.cells = cells
        self.height = height
    }

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        cells.count
    }

    func tableView(_: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        cells[indexPath.row]
    }

    func tableView(_: UITableView, heightForRowAt _: IndexPath) -> CGFloat {
        height
    }
}

final class CovESwipeDelegate: SwipableTableViewCellDelegate {
    private(set) var taps: [(SwipableCellButtonType, IndexPath?)] = []

    func swipeCellDidTap(on actionType: SwipableCellButtonType, with indexPath: IndexPath?) {
        taps.append((actionType, indexPath))
    }
}

final class CovESwitchDelegate: SwitchTableViewCellDelegate {
    private(set) var toggles = 0

    func didToggle(cell _: SwitchTableViewCell) {
        toggles += 1
    }
}

final class CovESelectionObserver: SelectionListViewModelObserver {
    private(set) var changes = 0

    func didChangeSelection() {
        changes += 1
    }
}

final class CovESelectionItemDelegate: SelectionItemViewDelegate {
    private(set) var taps: [IndexPath] = []

    func didTapAdditionalButton(at indexPath: IndexPath) {
        taps.append(indexPath)
    }
}

final class CovESelectionPresenter: SelectionListPresenterProtocol {
    let items: [SelectableViewModelProtocol]
    private(set) var selected: [Int] = []

    init(items: [SelectableViewModelProtocol]) {
        self.items = items
    }

    var numberOfItems: Int {
        items.count
    }

    func item(at index: Int) -> SelectableViewModelProtocol {
        items[index]
    }

    func selectItem(at index: Int) {
        selected.append(index)
    }
}

final class CovESelectionListController: SelectionListViewController<SelectionTitleTableViewCell> {
    override var selectableCellIdentifier: ReuseIdentifier<SelectionTitleTableViewCell>! {
        R.reuseIdentifier.selectionItemCellId
    }

    override var selectableCellNib: UINib? {
        UINib(resource: R.nib.selectionTitleTableViewCell)
    }
}
