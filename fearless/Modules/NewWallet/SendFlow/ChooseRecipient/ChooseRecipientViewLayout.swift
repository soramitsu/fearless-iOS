import UIKit

final class ChooseRecipientViewLayout: UIView {
    enum LayoutConstraints {
        static let iconWidth: CGFloat = 36
        static let textFieldHeight: CGFloat = 36
    }

    let navigationBar: BaseNavigationBar = {
        let view = BaseNavigationBar()
        view.backButton.setImage(R.image.iconBack(), for: .normal)
        return view
    }()

    let navigationTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .h3Title
        label.textColor = .white
        return label
    }()

    let tableView: UITableView = {
        let view = UITableView()
        view.backgroundColor = .black
        return view
    }()

    let searchView: InputTriangularedView = {
        let view = InputTriangularedView(frame: .zero)

        view.titleLabel.font = .h5Title

        view.actionView.image = R.image.iconClose()

        view.textField.backgroundColor = .clear
        view.textField.font = .p1Paragraph
        view.textField.clearButtonMode = .whileEditing
        return view
    }()

    var locale = Locale.current {
        didSet {
            if locale != oldValue {
                applyLocalization()
            }
        }
    }

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

        addSubview(searchView)
        searchView.snp.makeConstraints { make in
            make.top.equalTo(navigationBar.snp.bottom)
            make.leading.trailing.equalToSuperview()
        }

        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(searchView.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }

    func applyLocalization() {
        searchView.textField.placeholder = R.string.localizable.searchTextfieldPlaceholder(
            preferredLanguages: locale.rLanguages
        )
        navigationTitleLabel.text = R.string.localizable.chooseRecipientTitle(
            preferredLanguages: locale.rLanguages
        )
    }
}
