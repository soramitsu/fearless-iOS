@testable import fearless
import SoraUI
import UIKit
import XCTest

/// More reusable views: icons, option badges, account cells, section headers, text fields and generic rows.
@MainActor
final class CovEMoreViewsTests: XCTestCase {
    func testEthereumIconDrawsACircleWithItsSquares() throws {
        let squares = (0 ..< 4).map { index in
            EthereumIcon.Square(
                origin: CGPoint(x: CGFloat(index) * 4, y: CGFloat(index) * 3),
                color: [UIColor.red, .green, .blue, .yellow][index],
                sideSize: 12,
                rotation: 0.1 * CGFloat(index)
            )
        }
        let icon = EthereumIcon(radius: 16, squares: squares)
        XCTAssertEqual(icon.squares.count, 4)
        XCTAssertEqual(icon.radius, 16)
        XCTAssertEqual(squares[0], EthereumIcon.Square(origin: .zero, color: .red, sideSize: 12, rotation: 0))
        let size = CGSize(width: 32, height: 32)
        let image = UIGraphicsImageRenderer(size: size).image { renderer in
            icon.drawInContext(renderer.cgContext, fillColor: .white, size: size)
        }
        XCTAssertEqual(image.size, size)
        let corner = try XCTUnwrap(pixel(of: image, at: CGPoint(x: 0, y: 0)))
        let centre = try XCTUnwrap(pixel(of: image, at: CGPoint(x: 16, y: 16)))
        XCTAssertEqual(corner.alpha, 0, "Outside the circle stays transparent")
        XCTAssertGreaterThan(centre.alpha, 0, "The circle is filled")
    }

    func testOptionBadgeAccountCellAndAddressForm() {
        let options = ChainOptionsView()
        options.bind(to: ChainOptionsViewModel(text: "testnet", icon: BundleImageViewModel(image: R.image.iconClose())))
        XCTAssertEqual(options.label.text, "TESTNET")
        XCTAssertEqual(options.imageView.image, R.image.iconClose())
        XCTAssertEqual(options.layer.cornerRadius, ChainOptionsView.LayoutConstants.corderRadius)
        XCTAssertEqual(options.backgroundColor, R.color.colorWhite16())

        let cell = AccountInfoTableViewCell(style: .default, reuseIdentifier: nil)
        let delegate = CovEAccountCellDelegate()
        cell.delegate = delegate
        cell.bind(model: AccountInfoViewModel(title: "Account", address: "5Grw", name: "Main", icon: R.image.iconClose()))
        XCTAssertEqual(cell.detailsView.title, "Account")
        XCTAssertEqual(cell.detailsView.subtitle, "Main")
        XCTAssertEqual(cell.detailsView.iconImage, R.image.iconClose())
        cell.detailsView.sendActions(for: .touchUpInside)
        XCTAssertEqual(delegate.actions, 1)
        cell.frame = CGRect(x: 0, y: 0, width: 390, height: 64)
        cell.layoutIfNeeded()
        XCTAssertGreaterThanOrEqual(cell.separatorInset.left, 390, "The separator is pushed off screen")

        let form = EthereumAddressForRewardView(frame: .zero)
        XCTAssertEqual(form.ethereumAddressView.animatedInputField.textField.returnKeyType, .done)
        XCTAssertTrue(form.ethereumHintView.superview === form)
        let decoded = EthereumAddressForRewardView(coder: (try? CovEArchive.coder(for: UIView())) ?? NSCoder())
        XCTAssertTrue(decoded?.ethereumAddressView.superview === decoded)
        let window = CovEHost.window(for: form, frame: CGRect(x: 0, y: 100, width: 390, height: 160))
        defer { CovEHost.close(window) }
        XCTAssertLessThanOrEqual(form.ethereumAddressView.frame.maxY, form.ethereumHintView.frame.minY + 0.5)
    }

    func testHeadersTextFieldsAndTokenPairIcons() {
        let header = StatusSectionView(reuseIdentifier: "status")
        header.titleLabel.text = "ACTIVE"
        XCTAssertEqual(header.backgroundView?.backgroundColor, R.color.colorBlack())
        XCTAssertEqual(header.indicatorView.cornerRadius, 4)
        header.frame = CGRect(x: 0, y: 0, width: 390, height: 40)
        header.layoutIfNeeded()
        XCTAssertGreaterThan(header.titleLabel.frame.minX, header.indicatorView.frame.minX)

        let field = TriangularedTextField()
        XCTAssertEqual(field.fillColor, R.color.colorSemiBlack())
        XCTAssertEqual(field.textField.returnKeyType, .done)
        XCTAssertEqual(field.shadowOpacity, 0)
        let window = CovEHost.window(for: field, frame: CGRect(x: 16, y: 100, width: 358, height: 64))
        defer { CovEHost.close(window) }
        XCTAssertTrue(field.textField.superview === field)

        let pair = TokenPairIconsView(frame: CGRect(x: 0, y: 0, width: 60, height: 30))
        pair.layoutIfNeeded()
        XCTAssertEqual(pair.firstTokenIconView.frame, CGRect(x: 0, y: 0, width: 20, height: 20))
        XCTAssertEqual(pair.secondTokenIconView.frame.minX, 20 - 20 / 3, accuracy: 0.01)
        XCTAssertEqual(pair.secondTokenIconView.frame.minY, 10, accuracy: 0.01)
        pair.bind(viewModel: TokenPairsIconViewModel(firstTokenIconViewModel: nil, secondTokenIconViewModel: nil))
        XCTAssertNil(pair.firstTokenIconView.image)
        let decodedPair = TokenPairIconsView(coder: (try? CovEArchive.coder(for: UIView())) ?? NSCoder())
        XCTAssertEqual(decodedPair?.subviews.count, 2)
    }

    func testTextSectionNumberedLabelGenericRowAndMultilineCell() {
        let section = TextSectionView()
        section.titleLabel.text = "Title"
        section.valueLabel.text = "Value"
        XCTAssertEqual(section.stackView.arrangedSubviews, [section.titleLabel, section.valueLabel])
        XCTAssertEqual(section.stackView.spacing, UIConstants.bigOffset)

        let numbered = NumberedLabel(with: 3)
        numbered.textLabel.text = "Write down your phrase"
        XCTAssertEqual(numbered.numberLabel.text, "3.")
        XCTAssertEqual(numbered.textLabel.numberOfLines, 0)
        let window = CovEHost.window(for: numbered, frame: CGRect(x: 16, y: 100, width: 358, height: 40))
        defer { CovEHost.close(window) }
        XCTAssertTrue(numbered.numberLabel.superview === numbered)
        XCTAssertGreaterThanOrEqual(numbered.textLabel.frame.minX, numbered.numberLabel.frame.maxX)

        let row = GenericTitleValueView<UILabel, UILabel>()
        row.titleView.text = "Fee"
        row.valueView.text = "0.01 DOT"
        XCTAssertEqual(row.intrinsicContentSize.width, UIView.noIntrinsicMetric)
        XCTAssertEqual(row.intrinsicContentSize.height, max(row.titleView.intrinsicContentSize.height, row.valueView.intrinsicContentSize.height))
        let framed = GenericTitleValueView<UILabel, UIImageView>(frame: .zero)
        XCTAssertTrue(framed.valueView.superview is UIStackView)

        let cell = MultilineTableViewCell(style: .default, reuseIdentifier: nil)
        cell.bind(title: "A long message")
        XCTAssertEqual(cell.titleLabel.text, "A long message")
        XCTAssertEqual(cell.selectionStyle, .none)
        XCTAssertGreaterThanOrEqual(cell.separatorInset.left, UIConstants.horizontalInset)
    }

    func testTitleMultiValueViewLoadsBindsAndRebuildsSkeleton() {
        let view = TitleMultiValueView()
        view.titleLabel.text = "Network fee"
        view.equalsLabelsWidth = true
        let window = CovEHost.window(for: view, frame: CGRect(x: 16, y: 100, width: 358, height: 48))
        defer { CovEHost.close(window) }
        let before = view.subviews.count
        view.bind(viewModel: nil)
        XCTAssertEqual(view.valueTop.alpha, 0, "No view model means loading")
        XCTAssertEqual(view.subviews.count, before + 1)
        view.didAppearSkeleton()
        view.frame.size.width = 300
        view.didUpdateSkeletonLayout()
        XCTAssertEqual(view.subviews.count, before + 1, "A resized skeleton is replaced, not duplicated")
        view.didDisappearSkeleton()
        view.bind(viewModel: TitleMultiValueViewModel(title: "0.01 DOT", subtitle: nil))
        XCTAssertEqual(view.subviews.count, before)
        XCTAssertEqual(view.valueTop.text, "0.01 DOT")
        XCTAssertFalse(view.valueTop.isHidden)
        XCTAssertTrue(view.valueBottom.isHidden, "A missing subtitle hides its label")
        XCTAssertEqual(view.valueTop.alpha, 1)
        view.bindBalance(viewModel: nil)
        XCTAssertEqual(view.valueBottom.alpha, 0)
        view.bindBalance(viewModel: BalanceViewModel(amount: "1 DOT", price: "$5"))
        XCTAssertEqual(view.valueTop.text, "1 DOT")
        XCTAssertEqual(view.valueBottom.text, "$5")
        view.didUpdateSkeletonLayout()
        XCTAssertEqual(view.subviews.count, before)
    }

    func testSkeletonLoadableViewStartsRestartsAndStops() {
        let view = CovESkeletonHost(frame: CGRect(x: 0, y: 0, width: 200, height: 40))
        view.updateSkeletonLayout()
        XCTAssertNil(view.skeletonView, "Updating without a skeleton does nothing")
        view.startSkeletonAnimation()
        let first = view.skeletonView
        XCTAssertNotNil(first)
        XCTAssertEqual(first?.frame, CGRect(x: 120, y: 10, width: 80, height: 20), "The skeleton sits at the trailing edge")
        view.startSkeletonAnimation()
        XCTAssertTrue(view.skeletonView === first)
        view.updateSkeletonLayout()
        XCTAssertNotNil(view.skeletonView)
        XCTAssertFalse(view.skeletonView === first, "An update rebuilds the skeleton")
        XCTAssertNil(first?.superview)
        view.stopSkeletonAnimation()
        XCTAssertNil(view.skeletonView)
        XCTAssertTrue(view.subviews.isEmpty)
    }

    private func pixel(of image: UIImage, at point: CGPoint) -> (red: CGFloat, alpha: CGFloat)? {
        guard let cgImage = image.cgImage else { return nil }
        let scale = image.scale
        let x = Int(point.x * scale)
        let y = Int(point.y * scale)
        var data = [UInt8](repeating: 0, count: 4)
        guard let context = CGContext(
            data: &data, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.draw(cgImage, in: CGRect(x: -x, y: y - cgImage.height + 1, width: cgImage.width, height: cgImage.height))
        return (CGFloat(data[0]) / 255, CGFloat(data[3]) / 255)
    }
}

final class CovESkeletonHost: UIView, SkeletonLoadableView {
    var container: UIView {
        self
    }

    var skeletonSize = CGSize(width: 80, height: 20)
    var skeletonView: SkrullableView?
}

final class CovEAccountCellDelegate: AccountInfoTableViewCellDelegate {
    private(set) var actions = 0

    func accountInfoCellDidReceiveAction(_: AccountInfoTableViewCell) {
        actions += 1
    }
}
