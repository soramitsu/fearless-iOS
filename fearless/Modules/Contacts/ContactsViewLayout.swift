import UIKit

final class ContactsViewLayout: UIView {
    let tableView: UITableView = {
        let view = UITableView()
        view.backgroundColor = R.color.colorBlack19()
        view.separatorStyle = .none
        view.contentInset = UIEdgeInsets(
            top: 0,
            left: 0,
            bottom: UIConstants.bigOffset + UIConstants.actionHeight + UIConstants.bigOffset,
            right: 0
        )

        return view
    }()

    let emptyView = EmptyView()

    let createButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyEnabledStyle()
        return button
    }()

    let navigationBar: BaseNavigationBar = {
        let bar = BaseNavigationBar()
        bar.set(.push)
        bar.backButton.backgroundColor = R.color.colorWhite8()
        bar.backButton.rounded()
        bar.backgroundColor = R.color.colorBlack19()
        return bar
    }()

    var locale = Locale.current {
        didSet {
            applyLocalization()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = R.color.colorBlack19()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        navigationBar.backButton.rounded()
    }

    func showEmptyView() {
        tableView.isHidden = true
        emptyView.isHidden = false

        let title = R.string.localizable.nftStubTitle(preferredLanguages: locale.rLanguages)
        let description = R.string.localizable.historyEmptyDescription(preferredLanguages: locale.rLanguages)
        let viewModel = EmptyViewModel(title: title, description: description)
        emptyView.bind(viewModel: viewModel)
    }

    private func setupLayout() {
        addSubview(emptyView)
        addSubview(navigationBar)
        addSubview(tableView)
        addSubview(createButton)

        navigationBar.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
        }

        emptyView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        tableView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(navigationBar.snp.bottom).offset(UIConstants.bigOffset)
            make.bottom.equalTo(createButton.snp.top).offset(-UIConstants.bigOffset)
        }

        createButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.bottom.equalToSuperview().inset(UIConstants.bigOffset)
            make.height.equalTo(UIConstants.actionHeight)
        }
    }

    private func applyLocalization() {
        createButton.imageWithTitleView?.title = R.string.localizable.contactsCreateContact(
            preferredLanguages: locale.rLanguages
        )
    }
}
