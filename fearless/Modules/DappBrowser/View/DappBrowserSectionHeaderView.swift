import UIKit
import SoraUI

struct DappBrowserSectionHeaderViewViewModel {
    let title: String
    let isAllHidden: Bool
}

final class DappBrowserSectionHeaderView: UITableViewHeaderFooterView {
    var locale: Locale = .current {
        didSet {
            setupLocalization()
        }
    }

    let containerView: TriangularedView = {
        let containerView = TriangularedView()
        containerView.fillColor = R.color.colorWhite4()!
        containerView.highlightedFillColor = R.color.colorWhite4()!
        containerView.shadowOpacity = 0
        return containerView
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

    var allTapAction: (() -> Void)?

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        setup()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 42)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        moreButton.rounded()
    }

    func configure(model: DappBrowserSectionHeaderViewViewModel) {
        titleLabel.text = model.title
        moreButton.isHidden = model.isAllHidden
        containerView.cornerCut = .topLeft
        containerView.cornersRaduis = .topRight
    }

    // MARK: - Private methods

    private func setup() {
        moreButton.addAction(UIAction(handler: { [weak self] _ in
            self?.allButtonAction()
        }), for: .touchUpInside)

        let separator = UIFactory.default.createSeparatorView()
        contentView.addSubview(containerView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(moreButton)
        containerView.addSubview(separator)

        containerView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(16)
        }
        moreButton.snp.makeConstraints { make in
            make.width.greaterThanOrEqualTo(61)
            make.height.equalTo(24)
            make.trailing.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
        }
        titleLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.greaterThanOrEqualTo(moreButton.snp.leading).inset(16)
            make.leading.equalToSuperview().offset(16)
        }
        separator.snp.makeConstraints { make in
            make.top.equalTo(moreButton.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(1.0 / UIScreen.main.scale)
        }

        moreButton.setContentHuggingPriority(.required, for: .horizontal)
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
    }

    private func allButtonAction() {
        allTapAction?()
    }

    private func setupLocalization() {
        moreButton.setTitle("See all", for: .normal)
    }
}
