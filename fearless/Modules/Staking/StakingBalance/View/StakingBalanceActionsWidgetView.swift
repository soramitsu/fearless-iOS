import UIKit
import SoraUI

protocol StakingBalanceActionsWidgetViewDelegate: AnyObject {
    func didSelect(action: StakingBalanceAction)
}

final class StakingBalanceActionsWidgetView: UIView {
    weak var delegate: StakingBalanceActionsWidgetViewDelegate?

    private let backgroundView: UIView = TriangularedBlurView()

    private let bondMoreButton = StakingBalanceActionButton(action: .bondMore)
    private let unbondButton = StakingBalanceActionButton(action: .unbond)
    private let redeemButton = StakingBalanceActionButton(action: .redeem)

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()

        [bondMoreButton, unbondButton, redeemButton].forEach { button in
            button.addTarget(self, action: #selector(handleActionButton(sender:)), for: .touchUpInside)
        }
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

        let firstSeparator = UIView.createSeparator(color: R.color.colorLightGray()?.withAlphaComponent(0.24))
        let secondSeparator = UIView.createSeparator(color: R.color.colorLightGray()?.withAlphaComponent(0.24))
        let stackView = UIStackView(
            arrangedSubviews: [bondMoreButton, firstSeparator, unbondButton, secondSeparator, redeemButton]
        )
        [firstSeparator, secondSeparator].forEach { separator in
            separator.snp.makeConstraints { $0.width.equalTo(1) }
        }
        stackView.distribution = .equalSpacing

        backgroundView.addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(8)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }
    }

    @objc
    func handleActionButton(sender: UIControl) {
        guard let actionButton = sender as? StakingBalanceActionButton else { return }
        delegate?.didSelect(action: actionButton.action)
    }

    func bind(viewModel: StakingBalanceActionsWidgetViewModel) {
        bondMoreButton.imageWithTitleView?.title = viewModel.bondTitle
        unbondButton.imageWithTitleView?.title = viewModel.unbondTitle
        redeemButton.imageWithTitleView?.title = viewModel.redeemTitle
        redeemButton.isEnabled = viewModel.redeemActionIsAvailable
    }
}

private final class StakingBalanceActionButton: RoundedButton {
    let action: StakingBalanceAction

    init(action: StakingBalanceAction) {
        self.action = action
        super.init(frame: .zero)

        roundedBackgroundView?.backgroundColor = .clear
        roundedBackgroundView?.strokeColor = .clear
        roundedBackgroundView?.fillColor = .clear
        roundedBackgroundView?.shadowColor = .clear

        imageWithTitleView?.layoutType = .verticalImageFirst
        imageWithTitleView?.iconImage = action.iconImage
        imageWithTitleView?.titleFont = .p2Paragraph
        imageWithTitleView?.titleColor = R.color.colorWhite()
        imageWithTitleView?.title = action.title(for: .autoupdatingCurrent)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
