import UIKit
import SoraUI

final class NodeSelectionViewLayout: UIView {
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

    let editButton: UIButton = {
        let button = UIButton(type: .custom)
        return button
    }()

    let tableView: UITableView = {
        let view = UITableView()
        view.backgroundColor = .black
        return view
    }()

    let headerView = BorderedContainerView()

    let switchTitle: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .p1Paragraph
        return label
    }()

    let switchView: UISwitch = {
        let switchView = UISwitch()
        switchView.onTintColor = R.color.colorPink()
        return switchView
    }()

    let addNodeButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyEnabledStyle()
        return button
    }()

    var locale = Locale.current {
        didSet {
            applyLocalization()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .black

        setupLayout()
        applyLocalization()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func applyLocalization() {
        switchTitle.text = R.string.localizable.switchNodeAutoselectTitle(preferredLanguages: locale.rLanguages)
        addNodeButton.imageWithTitleView?.title = R.string.localizable.addNodeButtonTitle(preferredLanguages: locale.rLanguages)
        editButton.setTitle(R.string.localizable.commonEdit(preferredLanguages: locale.rLanguages), for: .normal)
    }

    func setupLayout() {
        addSubview(navigationBar)
        addSubview(headerView)
        addSubview(tableView)
        addSubview(addNodeButton)

        headerView.addSubview(switchTitle)
        headerView.addSubview(switchView)

        navigationBar.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.trailing.equalToSuperview().inset(UIConstants.defaultOffset)
            make.top.equalToSuperview()
        }

        headerView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.defaultOffset)
            make.top.equalTo(navigationBar.snp.bottom)
        }

        tableView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(headerView.snp.bottom)
        }

        addNodeButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.top.equalTo(tableView.snp.bottom).offset(UIConstants.bigOffset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.bigOffset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        switchTitle.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.top.equalToSuperview().offset(UIConstants.defaultOffset)
            make.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
        }

        switchView.snp.makeConstraints { make in
            make.trailing.equalToSuperview()
            make.top.equalToSuperview().offset(UIConstants.defaultOffset)
            make.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
            make.leading.equalTo(switchTitle.snp.trailing).offset(UIConstants.defaultOffset)
        }

        switchView.transform = CGAffineTransform(scaleX: 0.75, y: 0.75)

        navigationBar.setCenterViews([navigationTitleLabel])
        navigationBar.setRightViews([editButton])

        headerView.borderType = .bottom
        headerView.strokeColor = R.color.colorDarkGray() ?? .gray
        headerView.strokeWidth = 0.5
    }

    func bind(to viewModel: NodeSelectionViewModel) {
        navigationTitleLabel.text = viewModel.title
        switchView.isOn = viewModel.autoSelectEnabled

        let textColor = viewModel.autoSelectEnabled ? R.color.colorWhite() : R.color.colorGray()
        switchTitle.textColor = textColor
    }
}
