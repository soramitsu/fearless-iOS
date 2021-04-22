import UIKit

final class StakingBalanceViewLayout: UIView {
    let backgroundView: UIView = UIImageView(image: R.image.backgroundImage())

    let balanceWidget = StakingBalanceWidgetView()

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

        addSubview(balanceWidget)
        balanceWidget.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide).inset(8)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.height.equalTo(200)
        }
    }
}
