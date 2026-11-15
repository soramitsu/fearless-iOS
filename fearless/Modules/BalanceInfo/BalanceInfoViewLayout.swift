import UIKit
import SoraUI

final class BalanceInfoViewLayout: UIView {
    private let priceLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textAlignment = .center
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        return label
    }()

    private let balanceContainerView = UIFactory.default.createHorizontalStackView(spacing: UIConstants.defaultOffset)

    /// The changed digits of a new total roll into place (sun-lit redesign).
    private let balanceLabel: FWRollingLabel = {
        let label = FWRollingLabel()
        label.font = .h1Title
        label.lineBreakMode = .byCharWrapping
        label.textAlignment = .center
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        return label
    }()

    private let filteredPartLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorLightGray()
        label.textAlignment = .center
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        label.isHidden = true
        return label
    }()

    private let vStackView = UIFactory.default.createVerticalStackView(spacing: 2)
    private var portfolioLocale: Locale?
    /// Told when the total starts or stops loading; the wallet's sun shows it as sync activity.
    var onLoadingChange: ((Bool) -> Void)?
    var isLoadingTotal: Bool { skeletonView != nil }
    private var skeletonView: SkrullableView?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Only WalletMainContainer opts into the portfolio total's presentation roles.
    func configurePortfolioPresentation(locale: Locale) {
        guard FWAppearance.walletHeaderRestyled else { return }
        if portfolioLocale == nil {
            vStackView.removeArrangedSubview(balanceContainerView)
            vStackView.insertArrangedSubview(balanceContainerView, at: 0)
            filteredPartLabel.setContentCompressionResistancePriority(.required, for: .vertical)
            balanceLabel.accessibilityTraits.insert(.header)
            balanceLabel.textColor = FWSunlit.Palette.textPrimary
            balanceLabel.settledColor = FWSunlit.Palette.textPrimary
            filteredPartLabel.textColor = FWSunlit.Palette.textSecondary
        }
        portfolioLocale = locale
        updatePortfolioTypography()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updatePortfolioTypography()
    }

    private func updatePortfolioTypography() {
        guard let locale = portfolioLocale else { return }
        balanceLabel.font = .fw(.displayXL, locale: locale, compatibleWith: traitCollection)
        priceLabel.font = .fw(.labelM, locale: locale, compatibleWith: traitCollection)
        filteredPartLabel.font = .fw(.bodyS, locale: locale, compatibleWith: traitCollection)
    }

    func bind(viewModel: BalanceInfoViewModel?) {
        priceLabel.attributedText = viewModel?.dayChangeAttributedString
        let previous = balanceLabel.text
        if portfolioLocale != nil, let balance = viewModel?.balanceString,
           FWLivingBalance.claimFirstReveal(previous: balanceLabel.text, new: balance) {
            // Kit v3 "living balance": the wallet total counts up from zero on its first reveal after launch.
            balanceLabel.countUp(to: balance)
        } else {
            balanceLabel.setText(viewModel?.balanceString, animated: true)
            tickTotalIfChanged(from: previous, to: viewModel?.balanceString)
        }
        filteredPartLabel.text = viewModel?.filteredPartString
        filteredPartLabel.isHidden = viewModel?.filteredPartString == nil

        if viewModel == nil {
            balanceLabel.layoutIfNeeded()
            priceLabel.layoutIfNeeded()
            startLoadingIfNeeded()
        } else {
            stopLoadingIfNeeded()
        }
        onLoadingChange?(viewModel == nil)
    }

    /// Kit v4 value tick: the wallet total keeps its count and gains the line alone, after its first display.
    private func tickTotalIfChanged(from old: String?, to new: String?) {
        guard portfolioLocale != nil, let old, !old.isEmpty, let new, old != new,
              FWDigitRoll.isSameFormat(old, new) else { return }
        FWValueTick.line(under: balanceLabel, direction: FWDigitRoll.direction(from: Array(old), to: Array(new)))
    }

    #if DEBUG
        private static var debugTickObservation: NSObjectProtocol?

        /// The `tick` debug seam reaches the total too: one unit more in its last digit, through `bind`'s path.
        private func observeDebugTick() {
            Self.debugTickObservation.map(NotificationCenter.default.removeObserver)
            Self.debugTickObservation = NotificationCenter.default.addObserver(
                forName: FWShikibanDebugSeams.tickNotification, object: nil, queue: .main
            ) { [weak self] _ in
                guard let self, let old = self.balanceLabel.text, let new = FWRowSunlit.bumped(old) else { return }
                self.balanceLabel.setText(new, animated: true)
                self.tickTotalIfChanged(from: old, to: new)
            }
        }
    #endif

    private func setupLayout() {
        #if DEBUG
            observeDebugTick()
        #endif
        balanceContainerView.addArrangedSubview(balanceLabel)

        vStackView.alignment = .fill
        addSubview(vStackView)
        vStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        vStackView.addArrangedSubview(priceLabel)
        vStackView.addArrangedSubview(balanceContainerView)
        vStackView.addArrangedSubview(filteredPartLabel)

        balanceLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        priceLabel.setContentCompressionResistancePriority(.required, for: .vertical)
    }
}

extension BalanceInfoViewLayout: SkeletonLoadable {
    func didDisappearSkeleton() {
        skeletonView?.stopSkrulling()
    }

    func didAppearSkeleton() {
        skeletonView?.stopSkrulling()
        skeletonView?.startSkrulling()
    }

    func didUpdateSkeletonLayout() {
        guard let skeletonView = skeletonView else {
            return
        }

        if skeletonView.frame.size != frame.size {
            skeletonView.removeFromSuperview()
            self.skeletonView = nil
            setupSkeleton()
        }
    }

    func startLoadingIfNeeded() {
        guard skeletonView == nil else {
            return
        }

        balanceLabel.alpha = 0.0
        priceLabel.alpha = 0.0

        setupSkeleton()
    }

    func stopLoadingIfNeeded() {
        guard skeletonView != nil else {
            return
        }

        skeletonView?.stopSkrulling()
        skeletonView?.removeFromSuperview()
        skeletonView = nil

        balanceLabel.alpha = 1.0
        priceLabel.alpha = 1.0
    }

    private func setupSkeleton() {
        let spaceSize = frame.size

        guard spaceSize != .zero else {
            self.skeletonView = Skrull(size: .zero, decorations: [], skeletons: []).build()
            return
        }

        let skeletonView = Skrull(
            size: spaceSize,
            decorations: [],
            skeletons: createSkeletons(for: spaceSize)
        )
        .fillSkeletonStart(R.color.colorSkeletonStart()!)
        .fillSkeletonEnd(color: R.color.colorSkeletonEnd()!)
        .build()

        self.skeletonView = skeletonView

        skeletonView.frame = CGRect(origin: .zero, size: spaceSize)
        skeletonView.autoresizingMask = []
        insertSubview(skeletonView, aboveSubview: self)

        skeletonView.startSkrulling()
    }

    private func createSkeletons(for spaceSize: CGSize) -> [Skeletonable] {
        let defaultBigWidth = 72.0
        let defaultHeight = 16.0
        let smallHeight = 10.0

        let titleWidth = balanceLabel.text?.widthOfString(usingFont: balanceLabel.font)
        let incomeWidth = priceLabel.text?.widthOfString(usingFont: priceLabel.font)

        let titleSize = CGSize(width: titleWidth ?? defaultBigWidth, height: defaultHeight)
        let incomeSize = CGSize(width: incomeWidth ?? defaultBigWidth, height: smallHeight)

        return [
            SingleSkeleton.createRow(
                spaceSize: spaceSize,
                position: CGPoint(
                    x: UIConstants.offset12 + UIConstants.normalAddressIconSize.width + UIConstants.hugeOffset,
                    y: spaceSize.height / 2
                ),
                size: titleSize
            ),
            SingleSkeleton.createRow(
                spaceSize: spaceSize,
                position: CGPoint(
                    x: UIConstants.offset12 + UIConstants.normalAddressIconSize.width + UIConstants.hugeOffset,
                    y: spaceSize.height / 2 + defaultHeight / 2 + UIConstants.offset12
                ),
                size: incomeSize
            )
        ]
    }
}

/// The wallet total counts up from zero once per launch, the first time it shows a value above zero: before prices
/// load it may read "$0", and the count then runs from that zero to the real value.
enum FWLivingBalance {
    private static var counted = false

    static func claimFirstReveal(previous: String?, new: String) -> Bool {
        guard !counted, let value = FWDigitRoll.numericValue(new), value > 0 else { return false }
        if let previous, !previous.isEmpty, (FWDigitRoll.numericValue(previous) ?? 0) != 0 { return false }
        counted = true
        return true
    }
}
