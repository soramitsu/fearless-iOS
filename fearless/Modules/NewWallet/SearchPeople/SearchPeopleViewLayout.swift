import UIKit
import SoraUI

final class SearchPeopleViewLayout: UIView {
    enum LayoutConstants {
        static let iconWidth: CGFloat = 36
        static let textFieldHeight: CGFloat = 36
    }

    let navigationBar: BaseNavigationBar = {
        let view = BaseNavigationBar()
        view.backButton.setImage(R.image.iconClose(), for: .normal)
        return view
    }()

    let navigationTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .h3Title
        label.textColor = .white
        return label
    }()

    let scanButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(R.image.iconScanQr(), for: .normal)
        return button
    }()

    let tableView: UITableView = {
        let view = UITableView()
        view.backgroundColor = .black
        return view
    }()

    let headerView = UIView()

    let searchField: UITextField = {
        let view = UITextField()
        view.backgroundColor = .clear
        view.font = .p1Paragraph
        view.clearButtonMode = .whileEditing
        view.placeholder = R.string.localizable.walletContactsSearchPlaceholder_v110()
        return view
    }()

    let searchFieldBackgroundView: RoundedView = {
        let view = RoundedView()
        view.fillColor = R.color.colorAlmostBlack() ?? .darkGray
        return view
    }()

    let searchBorderView = BorderedContainerView()

    let contentView = UIView()

    let iconView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .center
        view.image = R.image.iconSearch()
        view.tintColor = R.color.colorGray()
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .black

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(navigationBar)
        navigationBar.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
        }

        navigationBar.setCenterViews([navigationTitleLabel])
        navigationBar.setRightViews([scanButton])

        addSubview(searchBorderView)
        searchBorderView.snp.makeConstraints { make in
            make.top.equalTo(navigationBar.snp.bottom)
            make.leading.trailing.equalToSuperview()
        }

        searchBorderView.addSubview(searchFieldBackgroundView)
        searchFieldBackgroundView.snp.makeConstraints { make in
            make.leading.top.equalToSuperview().offset(UIConstants.defaultOffset)
            make.trailing.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
            make.height.equalTo(LayoutConstants.textFieldHeight)
        }

        searchFieldBackgroundView.addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
            make.width.equalTo(LayoutConstants.iconWidth)
        }

        searchFieldBackgroundView.addSubview(searchField)
        searchField.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing)
            make.trailing.equalToSuperview().inset(UIConstants.defaultOffset)
            make.top.bottom.equalToSuperview()
        }

        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(searchBorderView.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }
}
