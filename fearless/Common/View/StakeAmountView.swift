import UIKit
import SoraFoundation

class StakeAmountView: UIView {
    private enum LayoutConstants {
        static let iconBackgroundSize = CGSize(width: 100, height: 100)
    }

    let iconBackground: ShadowRoundedBackground = {
        let view = ShadowRoundedBackground()
        view.shadowColor = R.color.colorPink1()!
        view.backgroundColor = R.color.colorBlack19()
        return view
    }()

    let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.tintColor = R.color.colorPink1()
        return imageView
    }()

    let amountLabel: UILabel = {
        let label = UILabel()
        label.font = .h2Title
        label.textColor = R.color.colorStrokeGray()
        label.textAlignment = .center
        label.numberOfLines = 2
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
        addSubview(iconBackground)
        addSubview(amountLabel)
        iconBackground.addSubview(iconImageView)

        iconBackground.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(UIConstants.defaultOffset)
            make.size.equalTo(LayoutConstants.iconBackgroundSize)
        }

        amountLabel.snp.makeConstraints { make in
            make.leading.bottom.trailing.equalToSuperview()
            make.top.equalTo(iconBackground.snp.bottom).offset(UIConstants.defaultOffset)
        }

        iconImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIConstants.defaultOffset)
        }
    }

    func bind(viewModel: StakeAmountViewModel) {
        amountLabel.attributedText = viewModel.amountTitle
        viewModel.iconViewModel?.loadAmountInputIcon(on: iconImageView, animated: true)
    }
}
