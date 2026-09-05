import UIKit
import SnapKit

final class WalletMainContainerViewLayout: UIView {
    private enum Constants {
        static let walletIconSize: CGFloat = 44.0
        static let accessoryButtonSize: CGFloat = 44.0
    }

    var locale: Locale = .current {
        didSet {
            applyLocalization()
        }
    }

    private let backgroundImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.image = R.image.backgroundImage()
        return imageView
    }()

    private let contentView: UIStackView = {
        let view = UIFactory.default.createVerticalStackView()
        view.alignment = .center
        return view
    }()

    let headerScrollView = UIScrollView()
    private var headerHeightLimit: Constraint?

    // MARK: - Navigation view properties

    private let navigationContainerView = UIView()

    let switchWalletButton: UIButton = {
        let button = UIButton()
        button.setImage(R.image.iconFearlessRounded(), for: .normal)
        return button
    }()

    let accountScoreView = AccountScoreView()

    private let walletNameTitle: UILabel = {
        let label = UILabel()
        label.font = .h4Title
        label.textAlignment = .left
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 2
        return label
    }()

    let selectNetworkButton = SelectedNetworkButton()

    let scanQRButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = R.color.colorWhite8()
        button.setImage(R.image.iconScanQr(), for: .normal)
        button.layer.cornerRadius = Constants.accessoryButtonSize / 2
        button.clipsToBounds = true
        return button
    }()

    let searchButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = R.color.colorWhite8()
        button.setImage(R.image.iconSearchWhite(), for: .normal)
        button.layer.cornerRadius = Constants.accessoryButtonSize / 2
        button.clipsToBounds = true
        return button
    }()

    // MARK: - Wallet balance view

    private let walletBalanceVStackView = UIFactory.default.createVerticalStackView(spacing: 4)
    let walletBalanceViewContainer = UIView()

    // MARK: - Address label

    let addressCopyableLabel = CopyableLabelView()

    // MARK: - FWSegmentedControl

    let segmentContainer = UIView()
    let segmentedControl = FWSegmentedControl()

    // MARK: - UIPageViewController

    let pageViewControllerContainer = UIView()

    let pageViewController: UIPageViewController = {
        let pageController = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal
        )
        return pageController
    }()

    // MARK: - Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
        updateHeaderScrolling()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateHeaderScrolling()
    }

    private func updateHeaderScrolling() {
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            headerHeightLimit?.activate()
        } else {
            headerHeightLimit?.deactivate()
        }
    }

    // MARK: - Public methods

    func bind(viewModel: WalletMainContainerViewModel) {
        walletNameTitle.text = viewModel.walletName
        selectNetworkButton.set(text: viewModel.selectedFilter, image: viewModel.selectedFilterImage)
        selectNetworkButton.accessibilityValue = viewModel.selectedFilter
        switchWalletButton.accessibilityValue = viewModel.walletName
        if let address = viewModel.address {
            addressCopyableLabel.isHidden = false
            addressCopyableLabel.bind(title: address)
        } else {
            addressCopyableLabel.isHidden = true
        }

        accountScoreView.bind(viewModel: viewModel.accountScoreViewModel)
    }

    func addBalance(_ view: UIView) {
        walletBalanceViewContainer.addSubview(view)
        view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func bind(accountScoreViewModel: AccountScoreViewModel) {
        accountScoreView.bind(viewModel: accountScoreViewModel)
    }

    // MARK: - Private methods

    private func applyLocalization() {
        let localizedItems = [
            R.string.localizable.сurrenciesStubText(preferredLanguages: locale.rLanguages),
            R.string.localizable.nftsStub(preferredLanguages: locale.rLanguages)
        ]
        segmentedControl.setSegmentItems(localizedItems)
    }

    // MARK: - Private layout methods

    private func setupLayout() {
        addSubview(backgroundImageView)
        backgroundImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(headerScrollView)
        headerScrollView.addSubview(contentView)
        headerScrollView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide.snp.top).offset(5)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(contentView.snp.height).priority(.high)
            headerHeightLimit = make.height.lessThanOrEqualTo(safeAreaLayoutGuide.snp.height).multipliedBy(0.55).constraint
        }
        contentView.snp.makeConstraints { make in
            make.edges.equalTo(headerScrollView.contentLayoutGuide)
            make.width.equalTo(headerScrollView.frameLayoutGuide)
        }

        setupNavigationViewLayout()
        setupWalletBalanceLayout()
        setupSegmentedLayout()
        setupListLayout()

        segmentContainer.isHidden = true
    }

    private func setupNavigationViewLayout() {
        let identityRow = UIStackView(arrangedSubviews: [switchWalletButton, walletNameTitle])
        identityRow.axis = .horizontal
        identityRow.alignment = .center
        identityRow.spacing = 12
        switchWalletButton.snp.makeConstraints { make in
            make.size.equalTo(Constants.walletIconSize)
        }
        let toolsRow = UIStackView(arrangedSubviews: [UIView(), searchButton, scanQRButton])
        toolsRow.axis = .horizontal
        toolsRow.alignment = .center
        toolsRow.spacing = 8
        selectNetworkButton.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(Constants.accessoryButtonSize)
            make.width.greaterThanOrEqualTo(Constants.accessoryButtonSize)
        }
        [searchButton, scanQRButton].forEach { button in
            button.snp.makeConstraints { make in make.size.equalTo(Constants.accessoryButtonSize) }
        }
        let headerStack = UIStackView(arrangedSubviews: [identityRow, selectNetworkButton, toolsRow])
        headerStack.axis = .vertical
        headerStack.spacing = 12
        navigationContainerView.addSubview(headerStack)
        headerStack.snp.makeConstraints { make in make.edges.equalToSuperview() }
        contentView.addArrangedSubview(navigationContainerView)
        navigationContainerView.snp.makeConstraints { make in
            make.width.equalTo(contentView.snp.width).offset(-2.0 * UIConstants.horizontalInset)
        }
        switchWalletButton.accessibilityLabel = NSLocalizedString("ux.switch_wallet", value: "Switch wallet", comment: "")
        selectNetworkButton.accessibilityLabel = NSLocalizedString("ux.choose_network", value: "Choose network", comment: "")
        searchButton.accessibilityLabel = NSLocalizedString("ux.search_assets", value: "Search assets", comment: "")
        scanQRButton.accessibilityLabel = NSLocalizedString("ux.scan_qr", value: "Scan QR code", comment: "")
    }

    private func setupWalletBalanceLayout() {
        // Account score is secondary context, below the balance rather than beside navigation.
        addressCopyableLabel.snp.makeConstraints { make in
            make.width.lessThanOrEqualTo(200)
            make.height.greaterThanOrEqualTo(44)
        }

        walletBalanceViewContainer.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(58)
        }

        walletBalanceVStackView.distribution = .fill
        walletBalanceVStackView.alignment = .center
        walletBalanceVStackView.addArrangedSubview(walletBalanceViewContainer)
        walletBalanceVStackView.addArrangedSubview(addressCopyableLabel)
        walletBalanceVStackView.addArrangedSubview(accountScoreView)
        walletBalanceVStackView.setCustomSpacing(4, after: addressCopyableLabel)

        contentView.setCustomSpacing(20, after: navigationContainerView)
        contentView.addArrangedSubview(walletBalanceVStackView)
        walletBalanceVStackView.snp.makeConstraints { make in
            make.width.equalTo(contentView.snp.width).offset(-2.0 * UIConstants.horizontalInset)
        }
        walletBalanceViewContainer.snp.makeConstraints { make in
            make.width.equalTo(walletBalanceVStackView)
        }
    }

    private func setupSegmentedLayout() {
        contentView.setCustomSpacing(20, after: walletBalanceVStackView)
        contentView.addArrangedSubview(segmentContainer)
        segmentContainer.addSubview(segmentedControl)
        segmentedControl.snp.makeConstraints { make in
            make.height.equalTo(32)
            make.width.equalTo(contentView.snp.width).offset(-2.0 * UIConstants.horizontalInset)
            make.edges.equalToSuperview()
        }
    }

    private func setupListLayout() {
        addSubview(pageViewControllerContainer)
        pageViewControllerContainer.addSubview(pageViewController.view)
        pageViewControllerContainer.snp.makeConstraints { make in
            make.top.equalTo(headerScrollView.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(safeAreaLayoutGuide)
        }
        pageViewController.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
