import UIKit
import SoraUI

class TitleMultiValueView: UIView {
    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorLightGray()
        label.font = UIFont.p1Paragraph
        return label
    }()

    let valueTop: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .p1Paragraph
        label.textAlignment = .right
        return label
    }()

    let valueLabelsStack: UIStackView = {
        let stackView = UIFactory.default.createVerticalStackView()
        stackView.alignment = .trailing
        return stackView
    }()

    let valueBottom: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorGray()
        label.font = .p2Paragraph
        label.textAlignment = .right
        return label
    }()

    let borderView: BorderedContainerView = {
        let view = BorderedContainerView()
        view.backgroundColor = .clear
        view.borderType = .bottom
        view.strokeWidth = 1.0
        view.strokeColor = R.color.colorDarkGray()!
        return view
    }()

    private var skeletonView: SkrullableView?
    private var sendReviewLayout = false
    private var sendReviewLoading = false
    private var skeletonFrames: [CGRect] = []

    /// An explicit opt-in for full-width transaction review values.
    func configureSendReview(
        locale: Locale, traits: UITraitCollection, topStyle: FWFontStyle, bottomStyle: FWFontStyle
    ) {
        sendReviewLayout = true
        titleLabel.font = .fw(.bodyS, locale: locale, compatibleWith: traits)
        valueTop.font = .fw(topStyle, locale: locale, compatibleWith: traits)
        valueBottom.font = .fw(bottomStyle, locale: locale, compatibleWith: traits)
        [titleLabel, valueTop, valueBottom].forEach {
            $0.numberOfLines = 0
            $0.lineBreakMode = .byCharWrapping
            $0.textAlignment = .left
            $0.setContentCompressionResistancePriority(.required, for: .vertical)
        }
        valueLabelsStack.alignment = .fill
        valueLabelsStack.spacing = 6
        titleLabel.snp.remakeConstraints { make in
            make.leading.trailing.top.equalToSuperview()
        }
        valueLabelsStack.snp.remakeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
        }
        valueTop.snp.remakeConstraints { $0.height.greaterThanOrEqualTo(ceil(valueTop.font.lineHeight)).priority(999) }
        valueBottom.snp.remakeConstraints {
            $0.height.greaterThanOrEqualTo(ceil(valueBottom.font.lineHeight)).priority(999)
        }
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard sendReviewLayout, sendReviewLoading, bounds.width > 0, bounds.height > 0 else { return }
        valueLabelsStack.layoutIfNeeded()
        let frames = [
            bounds, valueTop.convert(valueTop.bounds, to: self), valueBottom.convert(valueBottom.bounds, to: self)
        ]
        guard skeletonView == nil || skeletonFrames != frames else { return }
        skeletonView?.stopSkrulling()
        skeletonView?.removeFromSuperview()
        skeletonView = nil
        skeletonFrames = frames
        setupSkeleton()
    }

    var equalsLabelsWidth: Bool = false {
        didSet {
            if equalsLabelsWidth {
                valueTop.snp.makeConstraints { make in
                    make.width.equalTo(titleLabel.snp.width)
                }

                valueBottom.snp.makeConstraints { make in
                    make.width.equalTo(titleLabel.snp.width)
                }
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: TitleMultiValueViewModel?) {
        guard viewModel != nil else {
            startLoadingIfNeeded()
            return
        }

        stopLoadingIfNeeded()
        valueTop.text = viewModel?.title
        valueBottom.text = viewModel?.subtitle

        valueTop.isHidden = viewModel?.title == nil
        valueBottom.isHidden = viewModel?.subtitle == nil
    }

    func bindBalance(viewModel: BalanceViewModelProtocol?) {
        guard viewModel != nil else {
            startLoadingIfNeeded()
            return
        }

        stopLoadingIfNeeded()

        valueTop.text = viewModel?.amount
        valueBottom.text = viewModel?.price

        valueTop.isHidden = viewModel?.amount == nil
        valueBottom.isHidden = viewModel?.price == nil
    }

    func setupLayout() {
        addSubview(borderView)
        borderView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.top.bottom.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        addSubview(valueLabelsStack)
        valueLabelsStack.snp.makeConstraints { make in
            make.trailing.top.bottom.equalToSuperview()
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(8.0)
        }

        valueLabelsStack.addArrangedSubview(valueTop)
        valueLabelsStack.addArrangedSubview(valueBottom)
    }

    func startLoadingIfNeeded() {
        if sendReviewLayout {
            sendReviewLoading = true
            valueTop.alpha = 0
            valueBottom.alpha = 0
            setNeedsLayout()
            return
        }
        guard skeletonView == nil else {
            return
        }

        valueTop.alpha = 0.0
        valueBottom.alpha = 0.0

        setupSkeleton()
    }

    func stopLoadingIfNeeded() {
        sendReviewLoading = false
        skeletonFrames = []
        valueTop.alpha = 1.0
        valueBottom.alpha = 1.0

        guard skeletonView != nil else {
            return
        }

        skeletonView?.stopSkrulling()
        skeletonView?.removeFromSuperview()
        skeletonView = nil
    }

    private func setupSkeleton() {
        let spaceSize = frame.size

        guard spaceSize.height > 0 else {
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

        skeletonView.frame = CGRect(origin: .zero, size: spaceSize)
        skeletonView.autoresizingMask = []
        addSubview(skeletonView)

        self.skeletonView = skeletonView

        skeletonView.startSkrulling()
    }

    private func createSkeletons(for spaceSize: CGSize) -> [Skeletonable] {
        if sendReviewLayout {
            return [valueTop, valueBottom].filter { !$0.isHidden }.enumerated().map { index, label in
                let frame = label.convert(label.bounds, to: self)
                let size = CGSize(width: min(index == 0 ? 96 : 72, frame.width), height: min(12, frame.height))
                return SingleSkeleton.createRow(
                    spaceSize: spaceSize, position: CGPoint(x: frame.minX, y: frame.midY), size: size
                )
            }
        }
        let bigRowSize = CGSize(width: 72.0, height: 12.0)
        let smallRowSize = CGSize(width: 57.0, height: 6.0)

        return [
            SingleSkeleton.createRow(
                spaceSize: spaceSize,
                position: CGPoint(x: CGRectGetMaxX(valueLabelsStack.frame) - bigRowSize.width, y: CGRectGetMidY(valueTop.frame)),
                size: bigRowSize
            ),
            SingleSkeleton.createRow(
                spaceSize: spaceSize,
                position: CGPoint(x: CGRectGetMaxX(valueLabelsStack.frame) - bigRowSize.width, y: CGRectGetMidY(valueBottom.frame)),
                size: smallRowSize
            )
        ]
    }
}

extension TitleMultiValueView: SkeletonLoadable {
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
}
