import UIKit

final class WalletMainContainerViewLayout: UIView {
    private enum Constants {
        static let walletIconSize: CGFloat = 40.0
        static let accessoryButtonSize: CGFloat = 32.0
        static let issuesButtonSize = CGSize(width: 130, height: 24)
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

    // MARK: - Navigation view properties

    private let navigationContainerView = UIView()

    let switchWalletButton: UIButton = {
        let button = UIButton()
        button.setImage(R.image.iconFearlessRounded(), for: .normal)
        return button
    }()

    private let walletNameTitle: UILabel = {
        let label = UILabel()
        label.font = .h4Title
        label.textAlignment = .center
        return label
    }()

    let selectNetworkButton: SelectedNetworkButton = {
        let button = SelectedNetworkButton()
        button.titleLabel?.font = .p1Paragraph
        return button
    }()

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

    // MARK: - Ussues button

    let issuesButton: UIButton = {
        let button = UIButton()
        button.semanticContentAttribute = .forceRightToLeft
        button.setImage(R.image.iconWarning(), for: .normal)
        button.setTitle("Network Issues", for: .normal)
        button.titleLabel?.font = .h6Title
        button.layer.masksToBounds = true
        button.backgroundColor = R.color.colorWhite8()
        button.layer.cornerRadius = Constants.issuesButtonSize.height / 2
        button.setTextAndImage(spacing: 5)
        return button
    }()

    // MARK: - FWSegmentedControl

    let segmentedControl = FWSegmentedControl()

    // MARK: - UIPageViewController

    private let pageViewControllerContainer = UIView()

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
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public methods

    func bind(viewModel: WalletMainContainerViewModel) {
        walletNameTitle.text = viewModel.walletName
        selectNetworkButton.setTitle(viewModel.selectedChainName, for: .normal)
        if let address = viewModel.address {
            addressCopyableLabel.isHidden = false
            addressCopyableLabel.bind(title: address)
        } else {
            addressCopyableLabel.isHidden = true
        }

        issuesButton.isHidden = !viewModel.hasNetworkIssues
    }

    func addBalance(_ view: UIView) {
        walletBalanceViewContainer.addSubview(view)
        view.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
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

        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide.snp.top).offset(5)
            make.leading.trailing.equalToSuperview()
        }

        setupNavigationViewLayout()
        setupWalletBalanceLayout()
        setupSegmentedLayout()
        setupListLayout()
    }

    private func setupNavigationViewLayout() {
        navigationContainerView.addSubview(switchWalletButton)
        switchWalletButton.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview()
            make.size.equalTo(Constants.walletIconSize)
        }

        let walletInfoVStackView = UIFactory.default.createVerticalStackView(spacing: 6)
        walletInfoVStackView.alignment = .center
        walletInfoVStackView.distribution = .fill

        navigationContainerView.addSubview(walletInfoVStackView)
        walletInfoVStackView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.bottom.equalToSuperview()
            make.leading.greaterThanOrEqualTo(switchWalletButton.snp.trailing)
        }

        walletInfoVStackView.addArrangedSubview(walletNameTitle)
        walletInfoVStackView.addArrangedSubview(selectNetworkButton)
        selectNetworkButton.snp.makeConstraints { make in
            make.height.equalTo(22)
        }

        walletNameTitle.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.minimalOffset)
        }

        let accessoryButtonHStackView = UIFactory.default.createHorizontalStackView(spacing: 8)
        navigationContainerView.addSubview(accessoryButtonHStackView)
        accessoryButtonHStackView.snp.makeConstraints { make in
            make.leading.greaterThanOrEqualTo(walletInfoVStackView.snp.trailing)
            make.trailing.equalToSuperview()
            make.centerY.equalToSuperview()
        }

        [scanQRButton, searchButton].forEach { button in
            accessoryButtonHStackView.addArrangedSubview(button)
            button.snp.makeConstraints { make in
                make.size.equalTo(Constants.accessoryButtonSize)
            }
        }

        contentView.addArrangedSubview(navigationContainerView)
        navigationContainerView.snp.makeConstraints { make in
            make.width.equalTo(contentView.snp.width).offset(-2.0 * UIConstants.horizontalInset)
        }
    }

    private func setupWalletBalanceLayout() {
        addressCopyableLabel.snp.makeConstraints { make in
            make.width.lessThanOrEqualTo(200)
            make.height.equalTo(24)
        }

        issuesButton.snp.makeConstraints { make in
            make.size.equalTo(Constants.issuesButtonSize)
        }

        walletBalanceViewContainer.snp.makeConstraints { make in
            make.height.equalTo(58)
        }

        walletBalanceVStackView.distribution = .fill
        walletBalanceVStackView.addArrangedSubview(walletBalanceViewContainer)
        walletBalanceVStackView.addArrangedSubview(addressCopyableLabel)
        walletBalanceVStackView.addArrangedSubview(issuesButton)
        walletBalanceVStackView.setCustomSpacing(4, after: addressCopyableLabel)

        contentView.setCustomSpacing(32, after: navigationContainerView)
        contentView.addArrangedSubview(walletBalanceVStackView)
    }

    private func setupSegmentedLayout() {
        segmentedControl.isHidden = true
    }

    private func setupListLayout() {
        addSubview(pageViewControllerContainer)
        pageViewControllerContainer.addSubview(pageViewController.view)
        pageViewControllerContainer.snp.makeConstraints { make in
            make.top.equalTo(contentView.snp.bottom).offset(32)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom)
        }
        pageViewController.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
