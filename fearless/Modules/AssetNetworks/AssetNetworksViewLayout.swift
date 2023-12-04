import UIKit

final class AssetNetworksViewLayout: UIView {
    private enum LayoutConstants {
        static let switcherHeight: CGFloat = 32.0
    }

    let networkSwitcher = FWSegmentedControl()

    let sortButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(R.image.iconFilter(), for: .normal)
        return button
    }()

    let tableView: UITableView = {
        let view = UITableView(frame: .zero, style: .grouped)
        view.backgroundColor = .clear
        view.separatorStyle = .none
        view.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: UIConstants.bigOffset, right: 0)
        view.refreshControl = UIRefreshControl()
        return view
    }()

    var locale: Locale = .current {
        didSet {
            applyLocalization()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        drawSubviews()
        setupConstraints()
        applyLocalization()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func drawSubviews() {
        addSubview(networkSwitcher)
        addSubview(sortButton)
        addSubview(tableView)
    }

    private func setupConstraints() {
        networkSwitcher.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.defaultOffset)
            make.top.equalToSuperview().inset(UIConstants.defaultOffset)
            make.height.equalTo(LayoutConstants.switcherHeight)
        }

        sortButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.defaultOffset)
            make.size.equalTo(LayoutConstants.switcherHeight)
            make.top.equalToSuperview().inset(12)
            make.leading.equalTo(networkSwitcher.snp.trailing).offset(8)
        }

        tableView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.top.equalTo(networkSwitcher.snp.bottom).offset(UIConstants.defaultOffset)
            make.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
        }
    }

    private func applyLocalization() {
        networkSwitcher.setSegmentItems([
            R.string.localizable.commonAvailableNetworks(preferredLanguages: locale.rLanguages),
            R.string.localizable.commonMyNetworks(preferredLanguages: locale.rLanguages)
        ])
    }
}
