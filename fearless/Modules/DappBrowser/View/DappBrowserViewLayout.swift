import UIKit

final class DappBrowserViewLayout: UIView {
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

    private let navigationContainerView = UIView()

    let switchWalletButton: UIButton = {
        let button = UIButton()
        button.setImage(R.image.tonIcon(), for: .normal)
        return button
    }()

    let walletNameTitle: UILabel = {
        let label = UILabel()
        label.font = .h4Title
        label.textAlignment = .center
        return label
    }()

    let searchButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = R.color.colorWhite8()
        button.setImage(R.image.iconSearchWhite(), for: .normal)
        button.clipsToBounds = true
        return button
    }()

    let selectNetworkButton = SelectedNetworkButton()
    let segmentedControl = FWSegmentedControl()

    lazy var featuredView = DappBrowserFeaturedView()

    let tableContainer = UIView()
    let tableView: UITableView = {
        let view = UITableView(frame: .zero, style: .grouped)
        view.separatorStyle = .none
        view.contentInset = .zero
        view.backgroundColor = .clear
        view.contentInset = UIEdgeInsets(
            top: 0,
            left: 0,
            bottom: UIConstants.actionHeight,
            right: 0
        )
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        searchButton.rounded()
    }

    private func setup() {
        let walletInfoVStackView = UIFactory.default.createVerticalStackView(spacing: 6)
        walletInfoVStackView.alignment = .center
        walletInfoVStackView.distribution = .fill

        addSubview(backgroundImageView)
        addSubview(navigationContainerView)
        addSubview(tableContainer)
        tableContainer.addSubview(tableView)
        navigationContainerView.addSubview(switchWalletButton)
        navigationContainerView.addSubview(walletInfoVStackView)
        navigationContainerView.addSubview(searchButton)
        walletInfoVStackView.addArrangedSubview(walletNameTitle)
        walletInfoVStackView.addArrangedSubview(selectNetworkButton)

        backgroundImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        navigationContainerView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.leading.trailing.equalToSuperview()
        }
        switchWalletButton.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(16)
            make.size.equalTo(40)
        }
        walletInfoVStackView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.bottom.equalToSuperview().inset(16)
            make.leading.greaterThanOrEqualTo(switchWalletButton.snp.trailing)
        }
        selectNetworkButton.snp.makeConstraints { make in
            make.height.equalTo(22)
        }
        walletNameTitle.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.minimalOffset)
        }
        searchButton.snp.makeConstraints { make in
            make.size.equalTo(32)
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().inset(16)
        }
        let segmentContainer = UIView()
        addSubview(segmentContainer)
        segmentContainer.addSubview(segmentedControl)
        segmentedControl.snp.makeConstraints { make in
            make.height.equalTo(32)
            make.width.equalTo(segmentContainer.snp.width)
            make.edges.equalToSuperview()
        }
        segmentContainer.snp.makeConstraints { make in
            make.top.equalTo(navigationContainerView.snp.bottom)
            make.leading.trailing.equalToSuperview().inset(16)
        }
        tableContainer.snp.makeConstraints { make in
            make.top.equalTo(segmentContainer.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
        }
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func applyLocalization() {
        let localizedItems = [
            R.string.localizable.dappDiscoverTitle(preferredLanguages: locale.rLanguages),
            R.string.localizable.dappConnectedTitle(preferredLanguages: locale.rLanguages)
        ]
        segmentedControl.setSegmentItems(localizedItems)
    }
}
