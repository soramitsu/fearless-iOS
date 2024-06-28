import UIKit
import SnapKit

final class LiquidityPoolsOverviewViewLayout: UIView {
    enum Constants {
        static let topInset: CGFloat = 16
        static let bottomInset: CGFloat = 16
        static let sectionsOffset: CGFloat = 16
        static let navigationBarHeight: CGFloat = 62
    }

    let navigationBar: BaseNavigationBar = {
        let bar = BaseNavigationBar()
        bar.backgroundColor = .clear
        bar.set(.present)
        return bar
    }()

    let polkaswapImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.polkaswap()
        return imageView
    }()

    private let backgroundImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.image = R.image.backgroundImage()
        return imageView
    }()

    let scrollView = UIScrollView()
    let containerStackView: UIStackView = {
        let stackView = UIFactory.default.createVerticalStackView(spacing: 16)
        stackView.distribution = .fill
        stackView.alignment = .center
        return stackView
    }()

    let userPoolsContainerView = TriangularedBlurView()
    let availablePoolsContainerView = TriangularedBlurView()

    var userPoolsHeightConstraint: Constraint?
    var availablePoolsHeightConstraint: Constraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = R.color.colorBlack19()
        userPoolsContainerView.isHidden = true
        drawSubviews()
        setupConstraints()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(userPoolsCount: Int) {
        updateConstraints(with: userPoolsCount)
    }

    func addUserPoolsView(_ view: UIView) {
        userPoolsContainerView.addSubview(view)
        view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func addAvailablePoolsView(_ view: UIView) {
        availablePoolsContainerView.addSubview(view)
        view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func updateConstraints(with userPoolsCount: Int) {
        let totalHeight = frame.size.height - Constants.navigationBarHeight
        let isThereUserPoolsSection = userPoolsCount > 0

        let userSectionHeight = isThereUserPoolsSection ? LiquidityPoolConstants.liquidityPoolsListHeaderHeight + LiquidityPoolConstants.liquidityPoolsListCellHeight * Double(userPoolsCount) + 12 : 0
        let sectionOffset = isThereUserPoolsSection ? Constants.sectionsOffset : 0
        let totalAvailableSectionHeight = totalHeight - Constants.topInset - Constants.bottomInset - userSectionHeight - sectionOffset
        let availableSectionRowsCount = Int((totalAvailableSectionHeight - LiquidityPoolConstants.liquidityPoolsListHeaderHeight) / LiquidityPoolConstants.liquidityPoolsListCellHeight)
        let availableSectionHeight: CGFloat = LiquidityPoolConstants.liquidityPoolsListHeaderHeight + LiquidityPoolConstants.liquidityPoolsListCellHeight * Double(availableSectionRowsCount) + 4

        userPoolsContainerView.snp.updateConstraints { make in
            make.height.equalTo(userSectionHeight)
        }

        availablePoolsContainerView.snp.updateConstraints { make in
            make.height.equalTo(availableSectionHeight)
        }
    }

    private func drawSubviews() {
        addSubview(backgroundImageView)
        addSubview(navigationBar)
        addSubview(scrollView)
        scrollView.addSubview(userPoolsContainerView)
        scrollView.addSubview(availablePoolsContainerView)

//        scrollView.addSubview(containerStackView)
//        containerStackView.addArrangedSubview(userPoolsContainerView)
//        containerStackView.addArrangedSubview(availablePoolsContainerView)

        navigationBar.setLeftViews([navigationBar.backButton, polkaswapImageView])
    }

    private func setupConstraints() {
        scrollView.snp.makeConstraints { make in
            make.top.equalTo(navigationBar.snp.bottom)
            make.bottom.equalToSuperview().inset(24)
            make.width.equalTo(self)
            make.centerX.equalToSuperview()
        }
        backgroundImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        navigationBar.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview()
        }

//        containerStackView.snp.makeConstraints { make in
//            make.top.equalTo(navigationBar.snp.bottom)
//            make.bottom.lessThanOrEqualTo(self)
//            make.width.equalTo(self)
//            make.centerX.equalToSuperview()
//        }

        userPoolsContainerView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalTo(self).inset(16)
            userPoolsHeightConstraint = make.height.equalTo(0).constraint
        }

        availablePoolsContainerView.snp.makeConstraints { make in
            make.top.equalTo(userPoolsContainerView.snp.bottom).offset(16)
            make.leading.trailing.equalTo(self).inset(16)
            availablePoolsHeightConstraint = make.height.equalTo(0).constraint
            make.bottom.equalToSuperview()
        }

        updateConstraints(with: 0)
    }
}
