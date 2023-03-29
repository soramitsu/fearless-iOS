import UIKit
import SoraFoundation

final class SoraCardInfoBoardViewLayout: UIView {
    private enum LayoutConstants {
        static let statusButtonHeight: CGFloat = 33
        static let hideButtonSize: CGFloat = 32
    }

    let cardBackgroundImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.soraCardBoard()
        return imageView
    }()

    let statusButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = R.color.colorBlack19()
        button.titleLabel?.font = .capsTitle
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
        button.isEnabled = false
        return button
    }()

    let hideButton: ExtendedTouchAreaButton = {
        let button = ExtendedTouchAreaButton(type: .custom)
        button.setImage(R.image.iconCloseWhiteTransparent(), for: .normal)
        return button
    }()

    var locale = Locale.current {
        didSet {
            applyLocalization()
        }
    }

    private var viewModel: SoraCardInfoViewModel?

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

    func bind(viewModel: SoraCardInfoViewModel) {
        self.viewModel = viewModel

        statusButton.setTitle(viewModel.userStatus.title(for: locale).uppercased(), for: .normal)
        statusButton.setNeedsLayout()
        statusButton.layoutIfNeeded()
    }

    private func setupLayout() {
        addSubview(cardBackgroundImageView)
        addSubview(statusButton)
        addSubview(hideButton)

        cardBackgroundImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        statusButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().inset(UIConstants.minimalOffset)
            make.height.equalTo(LayoutConstants.statusButtonHeight)
        }

        hideButton.snp.makeConstraints { make in
            make.trailing.top.equalToSuperview()
            make.size.equalTo(LayoutConstants.hideButtonSize)
        }
    }

    private func applyLocalization() {
        statusButton.setTitle(viewModel?.userStatus.title(for: locale).uppercased(), for: .normal)
    }
}
