import UIKit

final class StakingBalanceViewLayout: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .red
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {}
}
