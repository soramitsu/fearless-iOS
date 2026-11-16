import BigInt
import SoraFoundation
import SSFModels
import SSFUtils
import UIKit
import XCTest
@testable import fearless

final class CovAStakingStateViewDelegateSpy: StakingStateViewDelegate {
    private(set) var calls: [String] = []
    func stakingStateViewDidReceiveMoreAction(_: StakingStateView) {
        calls.append("more")
    }

    func stakingStateViewDidReceiveStatusAction(_: StakingStateView) {
        calls.append("status")
    }
}

final class CovARewardEstimationDelegateSpy: RewardEstimationViewDelegate {
    private(set) var amounts: [Decimal?] = []
    private(set) var percentages: [Float] = []
    private(set) var infoRequests = 0
    func rewardEstimationView(_: RewardEstimationView, didChange amount: Decimal?) {
        amounts.append(amount)
    }

    func rewardEstimationView(_: RewardEstimationView, didSelect percentage: Float) {
        percentages.append(percentage)
    }

    func rewardEstimationDidRequestInfo(_: RewardEstimationView) {
        infoRequests += 1
    }
}

final class CovAStakingMainStateViewsTests: XCTestCase {
    private let locale = CovAFixtures.locale

    private func host(_ view: UIView, height: CGFloat = 320) -> UIWindow {
        let controller = UIViewController()
        let window = CovAViewInspector.host(controller)
        controller.view.addSubview(view)
        view.frame = CGRect(x: 16, y: 80, width: 358, height: height)
        view.setNeedsLayout()
        view.layoutIfNeeded()
        return window
    }

    private func nomination(_ status: NominationViewStatus, staked: String = "1 COV") -> LocalizableResource<NominationViewModelProtocol> {
        LocalizableResource { _ in
            NominationViewModel(
                totalStakedAmount: staked,
                totalStakedPrice: "$2",
                totalRewardAmount: "0.1 COV",
                totalRewardPrice: "$0.2",
                status: status,
                hasPrice: true,
                redeemableViewModel: StakingUnitInfoViewModel(value: "0.5 COV", subtitle: "$1"),
                unstakingViewModel: StakingUnitInfoViewModel(value: "0.2 COV", subtitle: "$0.4"),
                rewardViewTitle: "Rewards"
            )
        }
    }

    func testNominatorStateViewShowsEveryStatus() {
        let view = NominatorStateView()
        view.locale = locale
        let delegate = CovAStakingStateViewDelegateSpy()
        view.delegate = delegate
        let window = host(view)

        view.bind(viewModel: nomination(.active(era: 10)))
        XCTAssertEqual(view.stakeAmountView.valueLabel.text, "1 COV")
        XCTAssertTrue(CovAViewInspector.contains("10", in: view))

        view.bind(viewModel: nomination(.inactive(era: 11)))
        XCTAssertTrue(CovAViewInspector.contains("11", in: view))

        view.bind(viewModel: nomination(.waiting(eraCountdown: CovAStakingMainFixtures.eraCountdown(), nominationEra: 12)))
        view.didStart(with: 120)
        view.didCountdown(remainedInterval: 60)
        view.didStop(with: 0)

        view.bind(viewModel: nomination(.validatorsNotSelected))
        view.bind(viewModel: nomination(.undefined, staked: ""))
        view.layoutIfNeeded()

        CovAViewInspector.subviews(of: UIControl.self, in: view).forEach { $0.sendActions(for: .touchUpInside) }
        XCTAssertTrue(delegate.calls.contains("more"))

        view.setupSkeleton(options: [.stake, .rewards, .status, .price])
        view.didAppearSkeleton()
        view.didUpdateSkeletonLayout()
        view.didDisappearSkeleton()
        view.setupSkeleton(options: [])
        view.locale = Locale(identifier: "en_GB")
        window.isHidden = true
    }

    func testValidatorStateViewShowsStatuses() {
        let view = ValidatorStateView()
        view.locale = locale
        let window = host(view)
        for status in [ValidationViewStatus.active(era: 3), .inactive(era: 4), .undefined] {
            view.bind(viewModel: LocalizableResource { _ in
                ValidationViewModel(
                    totalStakedAmount: "5 COV",
                    totalStakedPrice: "$10",
                    totalRewardAmount: "1 COV",
                    totalRewardPrice: "$2",
                    status: status,
                    hasPrice: true
                )
            })
            XCTAssertEqual(view.stakeAmountView.valueLabel.text, "5 COV")
        }
        XCTAssertTrue(CovAViewInspector.contains("1 COV", in: view))
        view.locale = Locale(identifier: "en_GB")
        window.isHidden = true
    }

    func testRewardEstimationViewInputAndLoading() throws {
        let view = try XCTUnwrap(R.nib.rewardEstimationView(owner: nil))
        view.locale = locale
        view.uiFactory = UIFactory()
        view.amountFormatterFactory = AssetBalanceFormatterFactory()
        let delegate = CovARewardEstimationDelegateSpy()
        view.delegate = delegate
        let window = host(view, height: 260)

        view.startLoadingIfNeeded()
        view.didAppearSkeleton()
        view.didUpdateSkeletonLayout()
        view.didDisappearSkeleton()

        let balance = CovAFixtures.balanceFactory()
        let reward = RewardViewModelFactory(
            targetAssetInfo: CovAFixtures.chainAsset().assetDisplayInfo,
            selectedMetaAccount: CovAFixtures.wallet()
        )
        let rewards = LocalizableResource { locale in
            PeriodRewardViewModel(
                monthlyReward: reward.createRewardViewModel(reward: 0.1, targetReturn: 0.01, priceData: nil).value(for: locale),
                yearlyReward: reward.createRewardViewModel(reward: 1.2, targetReturn: 0.12, priceData: nil).value(for: locale)
            )
        }
        view.bind(viewModel: StakingEstimationViewModel(
            assetBalance: balance.createAssetBalanceViewModel(10, balance: 100, priceData: nil),
            rewardViewModel: rewards,
            assetInfo: CovAFixtures.chainAsset().assetDisplayInfo,
            inputLimit: 1000,
            amount: 10
        ))
        view.stopLoadingIfNeeded()
        XCTAssertTrue(CovAViewInspector.contains("12", in: view), "the yearly return is shown")

        let field = try XCTUnwrap(CovAViewInspector.subviews(of: UITextField.self, in: view).first)
        _ = view.textField(field, shouldChangeCharactersIn: NSRange(location: 0, length: 0), replacementString: "5")
        view.amountInputDidChange()
        let accessory = AmountInputAccessoryView(frame: CGRect(x: 0, y: 0, width: 358, height: 44))
        view.didSelect(on: accessory, percentage: 0.5)
        view.didSelectDone(on: accessory)
        CovAViewInspector.subviews(of: UIButton.self, in: view).forEach { $0.sendActions(for: .touchUpInside) }
        XCTAssertEqual(delegate.percentages, [0.5])
        XCTAssertFalse(delegate.amounts.isEmpty)

        view.bind(viewModel: StakingEstimationViewModel(
            assetBalance: balance.createAssetBalanceViewModel(0, balance: 100, priceData: nil),
            rewardViewModel: nil,
            assetInfo: CovAFixtures.chainAsset().assetDisplayInfo,
            inputLimit: 1000,
            amount: nil
        ))
        view.locale = Locale(identifier: "en_GB")
        window.isHidden = true
    }

    func testAnalyticsAndAlertsViews() {
        let analytics = RewardAnalyticsWidgetView()
        let window = host(analytics, height: 220)
        analytics.startLoading()
        analytics.setupSkeleton()
        analytics.didAppearSkeleton()
        analytics.didUpdateSkeletonLayout()
        analytics.didDisappearSkeleton()
        analytics.bind(viewModel: nil)
        analytics.stopLoading()
        XCTAssertFalse(analytics.isHidden && analytics.subviews.isEmpty)

        let alerts = AlertsView()
        final class CovAAlertsDelegateSpy: AlertsViewDelegate {
            var alerts: [StakingAlert] = []
            func didSelectStakingAlert(_ alert: StakingAlert) {
                alerts.append(alert)
            }
        }
        let delegate = CovAAlertsDelegateSpy()
        alerts.delegate = delegate
        window.rootViewController?.view.addSubview(alerts)
        alerts.frame = CGRect(x: 16, y: 320, width: 358, height: 400)
        alerts.bind(alerts: [
            .nominatorChangeValidators, .nominatorAllOversubscribed, .bondedSetValidators,
            .nominatorLowStake(LocalizableResource { _ in "low" }), .redeemUnbonded(LocalizableResource { _ in "0.5" }), .waitingNextEra
        ])
        alerts.layoutIfNeeded()
        CovAViewInspector.subviews(of: UIControl.self, in: alerts).forEach { $0.sendActions(for: .touchUpInside) }
        XCTAssertGreaterThan(delegate.alerts.count, 0)
        alerts.bind(alerts: [])
        window.isHidden = true
    }
}
