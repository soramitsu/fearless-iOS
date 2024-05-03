import UIKit
import SoraUI

final class LiquidityPoolsListViewLayout: UIView {
    let topBar: BorderedContainerView = {
        let view = BorderedContainerView()
        view.borderType = .bottom
        return view
    }()

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

    let tableView: SelfSizingTableView = {
        let view = SelfSizingTableView(frame: .zero)
        view.backgroundColor = .clear
        view.separatorStyle = .none
        view.contentInset = .zero
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
//        backgroundColor = R.color.colorWhite4()

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
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        moreButton.rounded()
    }

    private func drawSubviews() {
        addSubview(topBar)
        addSubview(tableView)

        topBar.addSubview(titleLabel)
        topBar.addSubview(moreButton)
    }

    private func setupConstraints() {
        topBar.snp.makeConstraints { make in
            make.height.equalTo(42)
            make.leading.trailing.top.equalToSuperview()
        }

        tableView.snp.makeConstraints { make in
            make.top.equalTo(topBar.snp.bottom).offset(8)
            make.leading.trailing.bottom.equalToSuperview()
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(12)
            make.centerY.equalToSuperview()
        }

        moreButton.snp.makeConstraints { make in
            make.width.equalTo(61)
            make.height.equalTo(24)
            make.trailing.equalToSuperview().inset(12)
            make.centerY.equalToSuperview()
        }
    }

    private func applyLocalization() {
        moreButton.setTitle(R.string.localizable.commonMore(preferredLanguages: locale.rLanguages).uppercased(), for: .normal)
    }
}
