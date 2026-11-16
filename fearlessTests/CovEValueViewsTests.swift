@testable import fearless
import RobinHood
import SoraUI
import UIKit
import XCTest

@MainActor
final class CovEValueViewsTests: XCTestCase {
    func testMultiValueViewHidesTheMissingBottomValueAndForwardsSpacing() {
        let view = MultiValueView()
        let window = CovEHost.window(for: view, frame: CGRect(x: 16, y: 100, width: 200, height: 44))
        defer { CovEHost.close(window) }

        view.bind(topValue: "10 DOT", bottomValue: "$50")
        XCTAssertEqual(view.valueTop.text, "10 DOT")
        XCTAssertEqual(view.valueBottom.text, "$50")
        XCTAssertFalse(view.valueBottom.isHidden)

        view.bind(topValue: "11 DOT", bottomValue: nil)
        XCTAssertEqual(view.valueBottom.text, "")
        XCTAssertTrue(view.valueBottom.isHidden)

        view.spacing = 7
        XCTAssertEqual(view.stackView.spacing, 7)
        XCTAssertEqual(view.spacing, 7)
        XCTAssertEqual(view.valueTop.textAlignment, .right)
    }

    func testTriangularedTitleMultiValueViewDrawsItsCardAndSkeletonWhileLoading() throws {
        let view = TriangularedTitleMultiValueView()
        let window = CovEHost.window(for: view, frame: CGRect(x: 16, y: 100, width: 358, height: 56))
        defer { CovEHost.close(window) }
        view.titleLabel.text = "Fee"

        XCTAssertTrue(view.borderView.superview === view.backgroundView)
        XCTAssertTrue(view.titleLabel.superview === view.backgroundView)
        XCTAssertEqual(view.backgroundView.strokeWidth, 0.5)
        XCTAssertEqual(view.backgroundView.fillColor, R.color.colorSemiBlack())

        view.bind(viewModel: nil)
        XCTAssertEqual(view.valueTop.alpha, 0)
        XCTAssertNotNil(CovEFind.mirror(view, "skeletonView", as: UIView.self), "a nil value shows the skeleton")
        view.didAppearSkeleton()
        view.didDisappearSkeleton()
        view.frame.size.height = 60
        view.didUpdateSkeletonLayout()
        let skeleton = try XCTUnwrap(CovEFind.mirror(view, "skeletonView", as: UIView.self))
        XCTAssertEqual(skeleton.frame.height, 60, "a resized row rebuilds the skeleton at its new size")

        view.bindBalance(viewModel: BalanceViewModel(amount: "1 KSM", price: nil))
        XCTAssertNil(CovEFind.mirror(view, "skeletonView", as: UIView.self))
        XCTAssertEqual(view.valueTop.text, "1 KSM")
        XCTAssertTrue(view.valueBottom.isHidden)
        XCTAssertEqual(view.valueTop.alpha, 1)

        view.bindBalance(viewModel: nil)
        XCTAssertEqual(view.valueBottom.alpha, 0)
        view.bind(viewModel: TitleMultiValueViewModel(title: nil, subtitle: "$3"))
        XCTAssertTrue(view.valueTop.isHidden)
        XCTAssertEqual(view.valueBottom.text, "$3")
    }

    func testSendReviewLayoutWrapsValuesAndDrawsRowSkeletonsOnlyWhileLoading() throws {
        let view = TitleMultiValueView()
        let window = CovEHost.window(for: view, frame: CGRect(x: 16, y: 100, width: 358, height: 120))
        defer { CovEHost.close(window) }
        view.titleLabel.text = "Recipient"
        view.bind(viewModel: TitleMultiValueViewModel(title: "5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY", subtitle: "Alice"))
        view.configureSendReview(locale: Locale(identifier: "en_US"), traits: window.traitCollection, topStyle: .monoS, bottomStyle: .bodyS)

        XCTAssertEqual(view.valueTop.numberOfLines, 0)
        XCTAssertEqual(view.valueTop.lineBreakMode, .byCharWrapping)
        XCTAssertEqual(view.valueTop.textAlignment, .left)
        XCTAssertEqual(view.valueLabelsStack.spacing, 6)
        view.layoutIfNeeded()
        XCTAssertNil(CovEFind.mirror(view, "skeletonView", as: UIView.self), "no skeleton without loading")

        view.startLoadingIfNeeded()
        view.layoutIfNeeded()
        XCTAssertEqual(view.valueTop.alpha, 0)
        let first = try XCTUnwrap(CovEFind.mirror(view, "skeletonView", as: UIView.self))
        view.setNeedsLayout()
        view.layoutIfNeeded()
        XCTAssertTrue(CovEFind.mirror(view, "skeletonView", as: UIView.self) === first, "unchanged frames keep the skeleton")

        view.frame.size.width = 300
        view.layoutIfNeeded()
        XCTAssertFalse(CovEFind.mirror(view, "skeletonView", as: UIView.self) === first, "new frames rebuild it")

        view.stopLoadingIfNeeded()
        XCTAssertNil(CovEFind.mirror(view, "skeletonView", as: UIView.self))
        XCTAssertEqual(view.valueBottom.alpha, 1)

        view.equalsLabelsWidth = true
        view.layoutIfNeeded()
        XCTAssertEqual(view.valueTop.frame.width, view.titleLabel.frame.width, accuracy: 0.5)
    }

    func testSectionTitleAndAlertTitleViewsLayOutTheirLabels() {
        let section = TableSectionTitleView()
        section.titleLabel.text = "Networks"
        let window = CovEHost.window(for: section, frame: CGRect(x: 0, y: 100, width: 390, height: 32))
        defer { CovEHost.close(window) }
        XCTAssertEqual(section.titleLabel.frame.minX, UIConstants.bigOffset, accuracy: 0.5)
        XCTAssertEqual(section.titleLabel.font, .p2Paragraph)

        let alert = AlertImageWithTitleView()
        alert.imageView.image = UIImage(systemName: "checkmark")
        alert.titleLabel.text = "A long confirmation message that has to wrap onto more than one line of text"
        alert.preferredWidth = 160
        alert.contentInsets = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        alert.verticalSpacing = 6
        alert.forceSizeCalculation()
        let size = alert.intrinsicContentSize
        XCTAssertEqual(size.width, 160)
        let imageHeight = alert.imageView.intrinsicContentSize.height
        XCTAssertGreaterThan(size.height, 10 + imageHeight + 6 + 10, "the wrapped title adds height")

        alert.frame = CGRect(origin: .zero, size: size)
        alert.invalidateLayout()
        alert.layoutIfNeeded()
        XCTAssertEqual(alert.imageView.frame.minY, 10)
        XCTAssertEqual(alert.titleLabel.frame.minY, alert.imageView.frame.maxY + 6, accuracy: 0.01)
        XCTAssertEqual(alert.titleLabel.frame.width, 160 - 24, accuracy: 0.01)
        XCTAssertEqual(alert.titleLabel.frame.midX, alert.bounds.midX, accuracy: 0.01)
    }

    func testAccessoryViewBindsIconTitleAndActionAvailability() throws {
        let view = AccessoryView(frame: CGRect(x: 0, y: 0, width: 390, height: 56))
        let button = RoundedButton()
        let title = UILabel()
        let icon = UIImageView()
        [icon, title, button].forEach(view.addSubview)
        let leading = title.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20)
        leading.isActive = true
        // The view is built from Interface Builder outlets; wire them the way a nib would (through key-value coding).
        view.setValue(BorderedContainerView(), forKey: "borderView")
        view.setValue(icon, forKey: "iconImageView")
        view.setValue(title, forKey: "titleLabel")
        view.setValue(leading, forKey: "titleLeading")
        view.setValue(button, forKey: "actionButton")
        XCTAssertTrue(view.contentView === view)
        XCTAssertFalse(view.extendsUnderSafeArea)

        view.bind(viewModel: AccessoryViewModel(title: "Next step", action: "Continue", icon: UIImage(systemName: "star"), numberOfLines: 2))
        XCTAssertEqual(title.text, "Next step")
        XCTAssertEqual(title.numberOfLines, 2)
        XCTAssertFalse(icon.isHidden)
        XCTAssertEqual(leading.constant, 45)
        XCTAssertEqual(button.imageWithTitleView?.title, "Continue")
        XCTAssertTrue(view.isActionEnabled)

        view.isActionEnabled = false
        XCTAssertFalse(button.isEnabled)
        XCTAssertEqual(button.alpha, 0.5)
        view.isActionEnabled = true
        XCTAssertTrue(button.isEnabled)
        XCTAssertEqual(button.alpha, 1)

        view.bind(viewModel: AccessoryViewModel(title: "Blocked", action: "Wait", shouldAllowAction: false))
        XCTAssertTrue(icon.isHidden)
        XCTAssertEqual(leading.constant, 0)
        XCTAssertFalse(view.isActionEnabled)
        view.isActionEnabled = true
        XCTAssertFalse(button.isEnabled, "a view model that forbids the action wins over the caller")
    }

    func testRoundedButtonStylesSetFillTitleAndOpacity() throws {
        let button = RoundedButton()
        let background = try XCTUnwrap(button.roundedBackgroundView)
        let titleView = try XCTUnwrap(button.imageWithTitleView)

        button.applyEnabledStyle()
        XCTAssertEqual(background.fillColor, R.color.colorDarkGray())
        XCTAssertEqual(background.strokeColor, .clear)
        XCTAssertEqual(titleView.titleColor, R.color.colorWhite())
        XCTAssertTrue(button.changesContentOpacityWhenHighlighted)

        button.applyDisabledStyle()
        XCTAssertEqual(background.fillColor, R.color.colorAlmostBlack())
        XCTAssertEqual(titleView.titleColor, R.color.colorDarkGray())
        XCTAssertEqual(button.contentOpacityWhenDisabled, 1)

        button.applySoraSecondaryStyle()
        XCTAssertEqual(background.fillColor, R.color.accentSecondary())
        XCTAssertEqual(background.strokeWidth, 2)
        XCTAssertEqual(titleView.titleColor, R.color.fgInverted())
        XCTAssertEqual(titleView.titleFont, UIFont.h4Title)
    }

    func testReorderControlImageIsTintedWhenTheTableShowsIt() throws {
        let table = UITableView(frame: CGRect(x: 0, y: 0, width: 390, height: 200))
        let source = CovEReorderSource()
        table.dataSource = source
        table.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        let window = CovEHost.window(for: table, frame: table.frame)
        defer { CovEHost.close(window) }
        table.setEditing(true, animated: false)
        table.reloadData()
        table.layoutIfNeeded()
        let cell = try XCTUnwrap(table.visibleCells.first)
        cell.layoutIfNeeded()

        cell.recolorReorderControl(.red)
        let control = cell.subviews.first { $0.classForCoder.description() == "UITableViewCellReorderControl" }
        if let control {
            let image = try XCTUnwrap(control.subviews.compactMap { $0 as? UIImageView }.first)
            XCTAssertEqual(image.tintColor, .red)
            XCTAssertEqual(image.image?.renderingMode, .alwaysTemplate)
        } else {
            // A system without the private reorder control leaves the cell untouched.
            XCTAssertTrue(cell.subviews.compactMap { $0 as? UIImageView }.allSatisfy { $0.tintColor != .red })
        }
    }

    func testTransactionHistoryItemsRoundTripThroughCoreData() throws {
        let facade = SubstrateStorageTestFacade()
        let repository: CoreDataRepository<TransactionHistoryItem, CDTransactionHistoryItem> = facade.createRepository()
        let full = TransactionHistoryItem(
            sender: "alice", receiver: "bob", status: .success, txHash: "0x01", timestamp: 1_700_000_000,
            fee: "125", blockNumber: 42, txIndex: 3, callPath: .transfer, call: Data([1, 2, 3])
        )
        let minimal = TransactionHistoryItem(
            sender: "carol", receiver: nil, status: .pending, txHash: "0x02", timestamp: 5,
            fee: "0", blockNumber: nil, txIndex: nil, callPath: CallCodingPath(moduleName: "Utility", callName: "batch"), call: nil
        )
        let queue = OperationQueue()
        let save = repository.saveOperation({ [full, minimal] }, { [] })
        queue.addOperations([save], waitUntilFinished: true)
        if case let .failure(error)? = save.result {
            XCTFail("save failed: \(error)")
        }

        let fetch = repository.fetchAllOperation(with: RepositoryFetchOptions())
        queue.addOperations([fetch], waitUntilFinished: true)
        guard case let .success(items) = fetch.result else {
            return XCTFail("fetch failed: \(String(describing: fetch.result))")
        }
        let byHash = Dictionary(uniqueKeysWithValues: items.map { ($0.txHash, $0) })
        let loadedFull = try XCTUnwrap(byHash["0x01"])
        XCTAssertEqual(loadedFull.receiver, "bob")
        XCTAssertEqual(loadedFull.status, .success)
        XCTAssertEqual(loadedFull.blockNumber, 42)
        XCTAssertEqual(loadedFull.txIndex, 3)
        // The stored module and call names survive; the path comes back as `.fromInit`, not the named case.
        XCTAssertEqual(loadedFull.callPath.moduleName, CallCodingPath.transfer.moduleName)
        XCTAssertEqual(loadedFull.callPath.callName, CallCodingPath.transfer.callName)
        XCTAssertEqual(loadedFull.call, Data([1, 2, 3]))
        let loadedMinimal = try XCTUnwrap(byHash["0x02"])
        XCTAssertNil(loadedMinimal.receiver)
        XCTAssertNil(loadedMinimal.blockNumber)
        XCTAssertNil(loadedMinimal.txIndex)
        XCTAssertEqual(loadedMinimal.callPath.moduleName, "Utility")
        XCTAssertEqual(loadedMinimal.callPath.callName, "batch")
        XCTAssertEqual(loadedMinimal.status, .pending)
    }
}

final class CovEReorderSource: NSObject, UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int { 2 }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = "Row \(indexPath.row)"
        cell.showsReorderControl = true
        return cell
    }

    func tableView(_: UITableView, canMoveRowAt _: IndexPath) -> Bool { true }

    func tableView(_: UITableView, moveRowAt _: IndexPath, to _: IndexPath) {}
}
