import UIKit

final class SoraCardInfoBoardViewLayout: UIView {
    private enum LayoutConstants {
        static let statusButtonHeight: CGFloat = 33
    }

    let cardBackgroundImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.soraCardBoard()
        return imageView
    }()

    let statusButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = R.color.colorBlack19()
        return button
    }()

    var locale = Locale.current

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        statusButton.rounded()
    }

    private func setupLayout() {
        addSubview(cardBackgroundImageView)
        addSubview(statusButton)

        cardBackgroundImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        statusButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().inset(UIConstants.minimalOffset)
            make.height.equalTo(LayoutConstants.statusButtonHeight)
        }
    }

    func bind(state: SoraCardState) {
        statusButton.setTitle(state.title(for: locale), for: .normal)
        statusButton.setNeedsLayout()
        statusButton.layoutIfNeeded()
    }
}
