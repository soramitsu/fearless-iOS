import Foundation
import UIKit
import SoraUI
import SoraFoundation

protocol NominationViewDelegate: AnyObject {
    func nominationViewDidReceiveMoreAction(_ nominationView: NominationView)
    func nominationViewDidReceiveStatusAction(_ nominationView: NominationView)
}

struct NominationSkeletonOptions: OptionSet {
    typealias RawValue = UInt8

    static let stake = NominationSkeletonOptions(rawValue: 1 << 0)
    static let rewards = NominationSkeletonOptions(rawValue: 1 << 1)
    static let status = NominationSkeletonOptions(rawValue: 1 << 2)
    static let price = NominationSkeletonOptions(rawValue: 1 << 3)

    let rawValue: UInt8

    init(rawValue: RawValue) {
        self.rawValue = rawValue
    }
}

final class NominationView: UIView, LocalizableViewProtocol {
    @IBOutlet private var backgroundView: UIView!
    @IBOutlet private var dataBackgroundView: UIView!
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var stakedTitleLabel: UILabel!
    @IBOutlet private var stakedAmountLabel: UILabel!
    @IBOutlet private var stakedPriceLabel: UILabel!
    @IBOutlet private var rewardTitleLabel: UILabel!
    @IBOutlet private var rewardAmountLabel: UILabel!
    @IBOutlet private var rewardPriceLabel: UILabel!
    @IBOutlet private var statusIndicatorView: RoundedView!
    @IBOutlet private var statusTitleLabel: UILabel!
    @IBOutlet private var statusDetailsLabel: UILabel!
    @IBOutlet private var statusNavigationView: UIImageView!

    @IBOutlet private var statusButton: TriangularedButton!

    private var skeletonView: SkrullableView?
    private var skeletonOptions: NominationSkeletonOptions?

    weak var delegate: NominationViewDelegate?
    private lazy var timer = CountdownTimer()
    private lazy var timeFormatter = TotalTimeFormatter()

    var locale = Locale.current {
        didSet {
            applyLocalization()
            applyViewModel()
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        applyLocalization()
        timer.delegate = self
    }

    deinit {
        timer.stop()
    }

    private var localizableViewModel: LocalizableResource<NominationViewModelProtocol>?

    func bind(viewModel: LocalizableResource<NominationViewModelProtocol>) {
        localizableViewModel = viewModel

        timer.stop()
        applyViewModel()
    }

    private func applyLocalization() {
        titleLabel.text = R.string.localizable
            .stakingYourStake(preferredLanguages: locale.rLanguages)
        stakedTitleLabel.text = R.string.localizable
            .stakingMainStakeBalanceStaked(preferredLanguages: locale.rLanguages)
        rewardTitleLabel.text = R.string.localizable
            .stakingTotalRewards_v190(preferredLanguages: locale.rLanguages)
    }

    private func applyViewModel() {
        guard let viewModel = localizableViewModel?.value(for: locale) else {
            return
        }

        stakedAmountLabel.text = viewModel.totalStakedAmount
        stakedPriceLabel.text = viewModel.totalStakedPrice
        rewardAmountLabel.text = viewModel.totalRewardAmount
        rewardPriceLabel.text = viewModel.totalRewardPrice

        if case .undefined = viewModel.status {
            toggleStatus(false)
        } else {
            toggleStatus(true)
        }

        var skeletonOptions: NominationSkeletonOptions = []

        if viewModel.totalStakedAmount.isEmpty {
            skeletonOptions.insert(.stake)
        }

        if viewModel.totalRewardAmount.isEmpty {
            skeletonOptions.insert(.rewards)
        }

        switch viewModel.status {
        case .undefined:
            skeletonOptions.insert(.status)
        case let .active(era):
            presentActiveStatus(for: era)
        case let .inactive(era):
            presentInactiveStatus(for: era)
        case let .waiting(eraCountdown, nominationEra):
            let remainingTime: TimeInterval? = eraCountdown.map { countdown in
                countdown.timeIntervalTillStart(targetEra: nominationEra + 1)
            }
            presentWaitingStatus(remainingTime: remainingTime)
        }

        skeletonOptions.formUnion([.rewards, .stake, .status])

        if !skeletonOptions.isEmpty, viewModel.hasPrice {
            skeletonOptions.insert(.price)
        }

        updateSkeletonIfNeeded(for: skeletonOptions)
    }

    private func toggleStatus(_ shouldShow: Bool) {
        statusTitleLabel.isHidden = !shouldShow
        statusDetailsLabel.isHidden = !shouldShow
        statusIndicatorView.isHidden = !shouldShow
        statusNavigationView.isHidden = !shouldShow
        statusButton.isUserInteractionEnabled = shouldShow
    }

    private func presentActiveStatus(for era: UInt32) {
        statusIndicatorView.fillColor = R.color.colorGreen()!
        statusTitleLabel.textColor = R.color.colorGreen()!

        statusTitleLabel.text = R.string.localizable
            .stakingNominatorStatusActive(preferredLanguages: locale.rLanguages).uppercased()
        statusDetailsLabel.text = R.string.localizable
            .stakingEraTitle("\(era)", preferredLanguages: locale.rLanguages).uppercased()
    }

    private func presentInactiveStatus(for era: UInt32) {
        statusIndicatorView.fillColor = R.color.colorRed()!
        statusTitleLabel.textColor = R.color.colorRed()!

        statusTitleLabel.text = R.string.localizable
            .stakingNominatorStatusInactive(preferredLanguages: locale.rLanguages).uppercased()
        statusDetailsLabel.text = R.string.localizable
            .stakingEraTitle("\(era)", preferredLanguages: locale.rLanguages).uppercased()
    }

    private func presentWaitingStatus(remainingTime: TimeInterval?) {
        statusIndicatorView.fillColor = R.color.colorTransparentText()!
        statusTitleLabel.textColor = R.color.colorTransparentText()!

        statusTitleLabel.text = R.string.localizable
            .stakingNominatorStatusWaiting(preferredLanguages: locale.rLanguages).uppercased()
        if let remainingTime = remainingTime {
            timer.start(with: remainingTime, runLoop: .main, mode: .common)
        } else {
            statusDetailsLabel.text = ""
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        updateSkeletonSizeIfNeeded()
    }

    private func updateSkeletonSizeIfNeeded() {
        guard let skeletonView = skeletonView, let skeletonOptions = skeletonOptions else {
            return
        }

        if skeletonView.frame != backgroundView.frame {
            setupSkeleton(options: skeletonOptions)
        }
    }

    private func updateSkeletonIfNeeded(for options: NominationSkeletonOptions) {
        stakedAmountLabel.isHidden = options.contains(.stake)
        stakedPriceLabel.isHidden = options.contains(.stake)

        rewardAmountLabel.isHidden = options.contains(.rewards)
        rewardPriceLabel.isHidden = options.contains(.rewards)

        setupSkeleton(options: options)
    }

    private func setupSkeleton(options: NominationSkeletonOptions) {
        skeletonView?.removeFromSuperview()
        skeletonView = nil
        skeletonOptions = nil

        guard !options.isEmpty else {
            return
        }

        skeletonOptions = options

        let spaceSize = backgroundView.frame.size

        let skeletons = createSkeletons(for: spaceSize, options: options)

        let skeletonView = Skrull(
            size: spaceSize,
            decorations: [],
            skeletons: skeletons
        )
        .fillSkeletonStart(R.color.colorSkeletonStart()!)
        .fillSkeletonEnd(color: R.color.colorSkeletonEnd()!)
        .build()

        skeletonView.frame = CGRect(origin: .zero, size: spaceSize)
        skeletonView.autoresizingMask = []
        insertSubview(skeletonView, aboveSubview: backgroundView)

        self.skeletonView = skeletonView

        skeletonView.startSkrulling()
    }

    private func createSkeletons(
        for spaceSize: CGSize,
        options: NominationSkeletonOptions
    ) -> [Skeletonable] {
        let bigRowSize = CGSize(width: 72.0, height: 12.0)
        let smallRowSize = CGSize(width: 57.0, height: 6.0)
        let topInset: CGFloat = 7.0
        let verticalSpacing: CGFloat = 10.0

        var skeletons: [Skeletonable] = []

        if options.contains(.stake) {
            skeletons.append(
                SingleSkeleton.createRow(
                    under: stakedTitleLabel,
                    containerView: backgroundView,
                    spaceSize: spaceSize,
                    offset: CGPoint(x: 0.0, y: topInset),
                    size: bigRowSize
                )
            )

            if options.contains(.price) {
                skeletons.append(
                    SingleSkeleton.createRow(
                        under: stakedTitleLabel,
                        containerView: backgroundView,
                        spaceSize: spaceSize,
                        offset: CGPoint(x: 0.0, y: topInset + bigRowSize.height + verticalSpacing),
                        size: smallRowSize
                    )
                )
            }
        }

        if options.contains(.rewards) {
            skeletons.append(
                SingleSkeleton.createRow(
                    under: rewardTitleLabel,
                    containerView: backgroundView,
                    spaceSize: spaceSize,
                    offset: CGPoint(x: 0.0, y: topInset),
                    size: bigRowSize
                )
            )

            if options.contains(.price) {
                skeletons.append(
                    SingleSkeleton.createRow(
                        under: rewardTitleLabel,
                        containerView: backgroundView,
                        spaceSize: spaceSize,
                        offset: CGPoint(x: 0.0, y: topInset + bigRowSize.height + verticalSpacing),
                        size: smallRowSize
                    )
                )
            }
        }

        if options.contains(.status) {
            let statusContainer = statusDetailsLabel.superview!
            let targetFrame = statusContainer.convert(statusContainer.bounds, to: self)

            let positionLeft = CGPoint(
                x: targetFrame.minX + bigRowSize.width / 2.0,
                y: targetFrame.midY
            )

            let positionRight = CGPoint(
                x: targetFrame.maxX - bigRowSize.width / 2.0,
                y: targetFrame.midY
            )

            let mappedSize = CGSize(
                width: spaceSize.skrullMapX(bigRowSize.width),
                height: spaceSize.skrullMapY(bigRowSize.height)
            )

            skeletons.append(
                SingleSkeleton(
                    position: spaceSize.skrullMap(point: positionLeft),
                    size: mappedSize
                ).round()
            )

            skeletons.append(
                SingleSkeleton(
                    position: spaceSize.skrullMap(point: positionRight),
                    size: mappedSize
                ).round()
            )
        }

        return skeletons
    }

    @IBAction private func actionOnMore() {
        delegate?.nominationViewDidReceiveMoreAction(self)
    }

    @IBAction private func actionOnStatus() {
        delegate?.nominationViewDidReceiveStatusAction(self)
    }
}

extension NominationView: CountdownTimerDelegate {
    func didStart(with interval: TimeInterval) {
        statusDetailsLabel.text = (try? timeFormatter.string(from: interval)) ?? ""
    }

    func didCountdown(remainedInterval: TimeInterval) {
        statusDetailsLabel.text = (try? timeFormatter.string(from: remainedInterval)) ?? ""
    }

    func didStop(with _: TimeInterval) {
        statusDetailsLabel.text = ""
    }
}

extension NominationView: SkeletonLoadable {
    func didDisappearSkeleton() {
        skeletonView?.stopSkrulling()
    }

    func didAppearSkeleton() {
        skeletonView?.startSkrulling()
    }

    func didUpdateSkeletonLayout() {
        updateSkeletonSizeIfNeeded()
    }
}
