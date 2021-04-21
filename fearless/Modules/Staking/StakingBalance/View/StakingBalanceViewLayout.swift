import UIKit

final class StakingBalanceViewLayout: UIView {
    let backgroundView: UIView = UIImageView(image: R.image.backgroundImage())

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
    }
}
