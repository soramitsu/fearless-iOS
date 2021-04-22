import UIKit

final class StakingBalanceViewLayout: UIView {
    let backgroundView: UIView = UIImageView(image: R.image.backgroundImage())

    let balanceWidget = StakingBalanceWidgetView()
    let actionsWidget = StakingBalanceActionsWidgetView()

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

        let scrollView = UIScrollView()
        addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.leading.bottom.trailing.equalToSuperview()
        }

        let contentView = UIView()
        scrollView.addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalTo(self)
        }

        contentView.addSubview(balanceWidget)
        balanceWidget.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(8)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        contentView.addSubview(actionsWidget)
        actionsWidget.snp.makeConstraints { make in
            make.top.equalTo(balanceWidget.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }
    }
}
