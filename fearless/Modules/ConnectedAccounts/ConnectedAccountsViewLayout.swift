import UIKit

final class ConnectedAccountsViewLayout: UIView {

    var locale: Locale = .current {
        didSet {
            applyLocalization()
        }
    }

    let navigationBar: BaseNavigationBar = {
        let bar = BaseNavigationBar()
        bar.set(.push)
        bar.backButton.backgroundColor = R.color.colorWhite8()
        bar.backgroundColor = R.color.colorBlack19()
        return bar
    }()

    let closeButton: UIButton = {
        let button = UIButton()
        button.setImage(R.image.iconClose(), for: .normal)
        button.layer.masksToBounds = true
        button.backgroundColor = R.color.colorWhite8()
        return button
    }()

    let tableView: UITableView = {
        let view = UITableView(frame: .zero, style: .grouped)
        view.separatorStyle = .none
        view.contentInset = .zero
        view.backgroundColor = R.color.colorBlack19()
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        navigationBar.backButton.rounded()
        closeButton.rounded()
    }

    // MARK: - Private methods

    private func setupLayout() {
        backgroundColor = R.color.colorBlack19()
        navigationBar.setRightViews([closeButton])
        closeButton.snp.makeConstraints { make in
            make.size.equalTo(32)
        }

        addSubview(navigationBar)
        navigationBar.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }

        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(navigationBar.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(safeAreaLayoutGuide)
        }
    }

    private func applyLocalization() {}
}
