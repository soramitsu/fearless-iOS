import UIKit
import SoraUI

final class ConnectedAccountsTableHeaderView: UITableViewHeaderFooterView {

    let containerView: TriangularedView = {
        let containerView = TriangularedView()
        containerView.fillColor = R.color.colorWhite4()!
        containerView.highlightedFillColor = R.color.colorWhite4()!
        containerView.shadowOpacity = 0
        containerView.cornerCut = .topLeft
        containerView.cornersRaduis = .topRight
        return containerView
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .h5Title
        label.textColor = .white
        return label
    }()

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        setup()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 44)
    }

    // MARK: - Private methods

    private func setup() {
        let separator = UIFactory.default.createSeparatorView()
        contentView.addSubview(containerView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(separator)

        containerView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(16)
        }
        titleLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(12)
        }
        separator.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(12)
            make.height.equalTo(1.0 / UIScreen.main.scale)
        }
    }
}
