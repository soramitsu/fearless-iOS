import UIKit

final class StakingBalanceUnbondingWidgetView: UIView {
    private let backgroundView: UIView = TriangularedBlurView()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .h5Title
        label.textColor = R.color.colorWhite()
        label.text = "Unbonding" // TODO:
        return label
    }()

    let emptyListLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorWhite()?.withAlphaComponent(0.64)
        label.text = "Your unbondings will appear here." // TODO:
        return label
    }()

    let moreButton: UIButton = {
        let button = UIButton()
        button.setImage(R.image.iconHorMore(), for: .normal)
        return button
    }()

    private let separatorView: UIView = {
        let view = UIView()
        view.backgroundColor = R.color.colorWhite()?.withAlphaComponent(0.24)
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

    private func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { $0.edges.equalToSuperview() }

        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.leading.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        addSubview(moreButton)
        moreButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalTo(titleLabel.snp.centerY)
        }

        addSubview(separatorView)
        separatorView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(15)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.height.equalTo(0.75)
        }

        addSubview(emptyListLabel)
        emptyListLabel.snp.makeConstraints { make in
            make.top.equalTo(separatorView.snp.bottom).offset(UIConstants.horizontalInset)
            make.leading.trailing.bottom.equalToSuperview().inset(UIConstants.horizontalInset)
        }
    }
}
