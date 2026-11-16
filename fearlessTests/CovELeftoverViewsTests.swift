@testable import fearless
import SoraUI
import UIKit
import XCTest

@MainActor
final class CovELeftoverViewsTests: XCTestCase {
    func testIconTitleHeaderBindsTitleIconAndBackground() throws {
        let header = IconTitleHeaderView(reuseIdentifier: "header")
        let titleView = ImageWithTitleView()
        header.contentView.addSubview(titleView)
        // Built from a nib in the app: wire the outlet the way the nib loader does.
        header.setValue(titleView, forKey: "titleView")

        let icon = UIImage(systemName: "star")
        header.bind(title: "Validators", icon: icon)
        XCTAssertEqual(titleView.title, "Validators")
        XCTAssertEqual(titleView.iconImage, icon)
        XCTAssertEqual(header.backgroundView?.backgroundColor, R.color.colorBlack(), "the legacy black backdrop")

        let custom = IconTitleHeaderView(reuseIdentifier: "custom")
        let customTitle = ImageWithTitleView()
        custom.setValue(customTitle, forKey: "titleView")
        custom.customBackgroundColor = .red
        custom.bind(title: "Nominators", icon: nil)
        XCTAssertEqual(customTitle.title, "Nominators")
        XCTAssertNil(customTitle.iconImage)
        // UITableViewHeaderFooterView ignores `backgroundColor`, so the custom colour path only skips the black backdrop.
        XCTAssertNil(custom.backgroundView, "a custom colour does not install the black backdrop")
    }

    func testInsettedLabelWidensByItsInsetsAndDrawsInsideThem() throws {
        let label = InsettedLabel(insets: UIEdgeInsets(top: 2, left: 6, bottom: 2, right: 10))
        label.text = "Badge"
        let plain = UILabel()
        plain.text = "Badge"
        XCTAssertEqual(label.intrinsicContentSize.width, plain.intrinsicContentSize.width + 16, accuracy: 0.5)
        XCTAssertEqual(label.intrinsicContentSize.height, plain.intrinsicContentSize.height, accuracy: 0.5)

        label.textColor = .white
        label.frame = CGRect(origin: .zero, size: label.intrinsicContentSize)
        let image = UIGraphicsImageRenderer(bounds: label.bounds).image { context in
            label.layer.render(in: context.cgContext)
        }
        XCTAssertEqual(image.size, label.bounds.size)
    }

    func testNetworkFeeViewBindsFeeTitleBalanceAndBorder() throws {
        let view = NetworkFeeView()
        let window = CovEHost.window(for: view, frame: CGRect(x: 16, y: 100, width: 358, height: 48))
        defer { CovEHost.close(window) }

        view.borderType = .top
        XCTAssertEqual(view.borderType, .top)
        XCTAssertEqual(view.borderView.borderType, .top)

        view.bind(viewModel: FeeViewModel(title: "Network fee", details: "0.01 DOT", isLoading: false, allowsEditing: false))
        XCTAssertEqual(view.titleLabel.text, "Network fee")

        let fee: FeeViewModelProtocol = CovEFeeBalanceViewModel(title: "Fee", amount: "0.02 DOT", price: "$0.10")
        view.bind(viewModel: fee)
        XCTAssertEqual(view.titleLabel.text, "Fee")
        XCTAssertNotNil(CovEFind.label("0.02 DOT", in: view), "a fee that is also a balance shows its amount")
    }

    func testHashCopiedEventDescribesTheCopiedHash() {
        let event = HashCopiedEvent(locale: Locale(identifier: "en"))
        XCTAssertTrue(event.autoDismissing)
        XCTAssertEqual(event.backgroundColor, R.color.colorColdGreen())
        XCTAssertEqual(event.image, R.image.iconCopy())
        XCTAssertEqual(event.titleText, R.string.localizable.applicationStatusViewHashCopiedTitle(preferredLanguages: ["en"]))
        XCTAssertEqual(
            event.descriptionText, R.string.localizable.applicationStatusViewHashCopiedDescription(preferredLanguages: ["en"])
        )
        XCTAssertFalse(HashCopiedEvent(locale: nil).titleText.isEmpty)
    }
}

struct CovEFeeBalanceViewModel: FeeViewModelProtocol, BalanceViewModelProtocol {
    let title: String
    let amount: String
    let price: String?
    var details: String { amount }
    var isLoading: Bool { false }
    var allowsEditing: Bool { false }
}
