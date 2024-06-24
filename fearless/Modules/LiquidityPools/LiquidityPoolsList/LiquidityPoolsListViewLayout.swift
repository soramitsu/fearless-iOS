import UIKit
import SoraUI
import SnapKit

final class LiquidityPoolsListViewLayout: UIView {
    var keyboardAdoptableConstraint: Constraint?

    let topBar: BorderedContainerView = {
        let view = BorderedContainerView()
        view.borderType = .bottom
        return view
    }()

    let contentView = UIView()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .h5Title
        label.textColor = .white
        return label
    }()

    let moreButton: UIButton = {
        let button = UIButton(type: .custom)
        button.titleLabel?.font = .capsTitle
        button.setTitleColor(.white, for: .normal)
        button.setImage(R.image.iconChevronRight(), for: .normal)
        button.semanticContentAttribute = .forceRightToLeft
        button.backgroundColor = R.color.colorWhite8()
        return button
    }()

    let backButton: UIButton = {
        let button = UIButton()
        button.setImage(R.image.iconBack(), for: .normal)
        button.layer.masksToBounds = true
        button.backgroundColor = R.color.colorWhite8()
        button.isHidden = true
        return button
    }()

    let separatorView = UIFactory.default.createSeparatorView()

    let tableView: UITableView = {
        let view = UITableView(frame: .zero)
        view.backgroundColor = .clear
        view.separatorStyle = .none
        view.contentInset = .zero
        return view
    }()

    let vStackView = UIFactory.default.createVerticalStackView(spacing: 8)

    let searchTextField: SearchTextField = {
        let searchTextField = UIFactory.default.createSearchTextField()
        searchTextField.triangularedView?.strokeWidth = 0
        return searchTextField
    }()

    let cancelButton: UIButton = {
        let button = UIButton()
        button.titleLabel?.font = .h4Title
        return button
    }()

    var locale: Locale = .current {
        didSet {
            applyLocalization()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = R.color.colorBlack19()
        drawSubviews()
        setupConstraints()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: LiquidityPoolListViewModel) {
        titleLabel.text = viewModel.titleLabelText
        moreButton.isHidden = !viewModel.moreButtonVisible
        backButton.isHidden = !viewModel.backgroundVisible
        searchTextField.isHidden = !viewModel.refreshAvailable
        separatorView.isHidden = viewModel.refreshAvailable

        tableView.refreshControl = viewModel.refreshAvailable ? UIRefreshControl() : nil
        tableView.isScrollEnabled = viewModel.refreshAvailable

        backgroundColor = viewModel.backgroundVisible ? R.color.colorBlack19() : .clear

        titleLabel.snp.remakeConstraints { make in
            make.centerY.equalToSuperview()

            if viewModel.isEmbed {
                make.leading.equalToSuperview().inset(12)
            } else {
                make.centerX.equalToSuperview()
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        moreButton.rounded()
        backButton.rounded()
    }

    private func drawSubviews() {
        addSubview(vStackView)

        vStackView.addArrangedSubview(topBar)
        vStackView.addArrangedSubview(searchTextField)
        vStackView.addArrangedSubview(separatorView)
        addSubview(contentView)
        contentView.addSubview(tableView)

        topBar.addSubview(titleLabel)
        topBar.addSubview(moreButton)
        topBar.addSubview(backButton)
    }

    private func setupConstraints() {
        vStackView.snp.makeConstraints { make in
            keyboardAdoptableConstraint = make.bottom.lessThanOrEqualToSuperview().constraint
            make.leading.trailing.top.equalToSuperview()
        }

        separatorView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(1.0 / UIScreen.main.scale)
        }

        topBar.snp.makeConstraints { make in
            make.height.equalTo(42)
            make.leading.trailing.equalToSuperview()
        }

        contentView.snp.makeConstraints { make in
            make.top.equalTo(vStackView.snp.bottom).offset(8)
            make.leading.trailing.bottom.equalToSuperview()
        }

        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        titleLabel.snp.makeConstraints { make in
            make.centerX.centerY.equalToSuperview()
        }

        searchTextField.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(8)
            make.height.equalTo(32)
        }

        moreButton.snp.makeConstraints { make in
            make.width.equalTo(61)
            make.height.equalTo(24)
            make.trailing.equalToSuperview().inset(12)
            make.centerY.equalToSuperview()
        }

        backButton.snp.makeConstraints { make in
            make.size.equalTo(32)
            make.leading.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
        }
    }

    private func applyLocalization() {
        moreButton.setTitle(R.string.localizable.commonMore(preferredLanguages: locale.rLanguages).uppercased(), for: .normal)
        searchTextField.textField.placeholder = R.string.localizable.manageAssetsSearchHint(
            preferredLanguages: locale.rLanguages
        )
    }
}
