import UIKit

final class SelectExportAccountViewLayout: UIView {
    // MARK: - UI

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .h2Title
        label.numberOfLines = 0
        return label
    }()

    private let profileInfoView: DetailsTriangularedView = {
        let view = DetailsTriangularedView()
        view.fillColor = R.color.colorDarkGray() ?? .gray
        view.titleLabel.font = .p1Paragraph
        view.titleLabel.textColor = R.color.colorWhite()
        view.subtitleLabel?.font = .p2Paragraph
        view.subtitleLabel?.textColor = R.color.colorLightGray()
        return view
    }()

    let tableView: UITableView = {
        let tableView = UITableView()
        tableView.backgroundColor = R.color.colorBlack()
        return tableView
    }()

    let continueButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        return button
    }()

    // MARK: - Constructors

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Locale

    var locale = Locale.current {
        didSet {
            if locale != oldValue {
                applyLocalization()
            }
        }
    }

    func applyLocalization() {
        titleLabel.text = "What accounts in the wallet do you want to export?"
        continueButton.imageWithTitleView?.title = "Continue"
    }

    // MARK: - Public methods

    func configureProfileInfo(
        title: String,
        subtitle: String,
        icon: UIImage?
    ) {
        profileInfoView.title = title
        profileInfoView.subtitle = subtitle
        profileInfoView.iconView.image = icon
    }

    // MARK: - Private methods

    private func configure() {
        tableView.separatorStyle = .none
        tableView.registerClassForCell(SelectableExportAccountTableCell.self)
    }

    private func setupLayout() {
        backgroundColor = R.color.colorBlack()

        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide).inset(UIConstants.bigOffset)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        addSubview(profileInfoView)
        profileInfoView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(25)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.height.equalTo(UIConstants.triangularedViewHeight)
        }

        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(profileInfoView.snp.bottom).offset(17)
            make.leading.trailing.bottom.equalToSuperview()
        }

        addSubview(continueButton)
        continueButton.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.actionHeight)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
        }
    }
}
