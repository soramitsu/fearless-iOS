import UIKit

final class StakingBalanceWidgetView: UIView {
    let backgroundView: UIView = TriangularedBlurView()

    let balanceTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Balance"
        label.font = .h5Title
        label.textColor = R.color.colorWhite()
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(balanceTitleLabel)
        balanceTitleLabel.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }
    }
}
