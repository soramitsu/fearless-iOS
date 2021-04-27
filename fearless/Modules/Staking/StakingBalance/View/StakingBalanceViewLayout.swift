import UIKit
import SnapKit

final class StakingBalanceViewLayout: UIView {
    let backgroundView: UIView = UIImageView(image: R.image.backgroundImage())

    let navBarBlurView: UIView = {
        let blurView = TriangularedBlurView()
        blurView.cornerCut = .none
        return blurView
    }()

    var navBarBlurViewHeightConstraint: Constraint!
    let balanceWidget = StakingBalanceWidgetView()
    let actionsWidget = StakingBalanceActionsWidgetView()
    let unbondingWidget = StakingBalanceUnbondingWidgetView()

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

        addSubview(navBarBlurView)
        navBarBlurView.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
            self.navBarBlurViewHeightConstraint = make.height.equalTo(0).constraint
            self.navBarBlurViewHeightConstraint.activate()
        }

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

        contentView.addSubview(unbondingWidget)
        unbondingWidget.snp.makeConstraints { make in
            make.top.equalTo(actionsWidget.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalToSuperview()
        }
    }
}
