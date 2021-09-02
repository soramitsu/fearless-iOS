import UIKit
import SoraUI

struct StakingStateSkeletonOptions: OptionSet {
    typealias RawValue = UInt8

    static let stake = StakingStateSkeletonOptions(rawValue: 1 << 0)
    static let rewards = StakingStateSkeletonOptions(rawValue: 1 << 1)
    static let status = StakingStateSkeletonOptions(rawValue: 1 << 2)
    static let price = StakingStateSkeletonOptions(rawValue: 1 << 3)

    let rawValue: UInt8

    init(rawValue: RawValue) {
        self.rawValue = rawValue
    }
}

protocol StakingStateViewDelegate: AnyObject {
    func stakingStateViewDidReceiveMoreAction(_ view: StakingStateView)
    func stakingStateViewDidReceiveStatusAction(_ view: StakingStateView)
}

class StakingStateView: UIView {
    weak var delegate: StakingStateViewDelegate?

    let backgroundView: UIView = TriangularedBlurView()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorWhite()
        return label
    }()

    let iconMore = UIImageView(image: R.image.iconHorMore())

    let stakeTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorTransparentText()
        return label
    }()

    let stakeAmountView: MultiValueView = createMultiValueView()

    let stakeContainer: UIStackView = createStackView()

    let rewardsContainer: UIStackView = createStackView()

    let rewardTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorTransparentText()
        return label
    }()

    let rewardAmountView: MultiValueView = createMultiValueView()

    let borderView: BorderedContainerView = {
        let view = UIFactory.default.createBorderedContainerView()
        view.borderType = .top
        view.strokeColor = R.color.colorBlurSeparator()!
        view.isUserInteractionEnabled = false
        return view
    }()

    let statusView: GenericTitleValueView<TitleStatusView, IconDetailsView> = {
        let statusView = TitleStatusView()
        statusView.mode = .indicatorTile
        statusView.spacing = 8.0
        statusView.titleLabel.font = .capsTitle

        let detailsView = IconDetailsView()
        detailsView.mode = .detailsIcon
        detailsView.spacing = 0.0
        detailsView.detailsLabel.font = .capsTitle
        detailsView.detailsLabel.textColor = R.color.colorTransparentText()
        detailsView.imageView.image = R.image.iconSmallArrow()
        detailsView.iconWidth = 24.0
        detailsView.detailsLabel.numberOfLines = 1

        return GenericTitleValueView(titleView: statusView, valueView: detailsView)
    }()

    let statusButton: TriangularedButton = {
        let button = createButton()
        button.triangularedView?.cornerCut = .bottomRight
        button.addTarget(self, action: #selector(actionOnStatus), for: .touchUpInside)
        return button
    }()

    let moreButton: TriangularedButton = {
        let button = createButton()
        button.triangularedView?.cornerCut = .topLeft
        button.addTarget(self, action: #selector(actionOnMore), for: .touchUpInside)
        return button
    }()

    private var skeletonView: SkrullableView?
    private var skeletonOptions: StakingStateSkeletonOptions?

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // swiftlint:disable:next function_body_length
    func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(iconMore)
        iconMore.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(16.0)
            make.top.equalToSuperview().inset(12.0)
        }

        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.top.equalToSuperview().inset(16.0)
            make.trailing.lessThanOrEqualTo(iconMore.snp.leading).offset(16.0)
        }

        addSubview(stakeContainer)
        stakeContainer.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(16.0)
            make.top.equalTo(titleLabel.snp.bottom).offset(17.0)
            make.trailing.equalTo(backgroundView.snp.centerX).offset(2.0)
        }

        stakeContainer.addArrangedSubview(stakeTitleLabel)
        stakeContainer.addArrangedSubview(stakeAmountView)

        addSubview(rewardsContainer)
        rewardsContainer.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(16.0)
            make.top.equalTo(titleLabel.snp.bottom).offset(17.0)
            make.leading.equalTo(backgroundView.snp.centerX)
        }

        rewardsContainer.addArrangedSubview(rewardTitleLabel)
        rewardsContainer.addArrangedSubview(rewardAmountView)

        addSubview(borderView)
        borderView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16.0)
            make.top.equalTo(stakeContainer.snp.bottom).offset(25.0)
            make.bottom.equalToSuperview()
            make.height.equalTo(44.0)
        }

        borderView.addSubview(statusView)
        statusView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        insertSubview(moreButton, aboveSubview: backgroundView)
        moreButton.snp.makeConstraints { make in
            make.leading.trailing.top.equalTo(backgroundView)
            make.bottom.equalTo(borderView.snp.top)
        }

        insertSubview(statusButton, aboveSubview: backgroundView)
        statusButton.snp.makeConstraints { make in
            make.leading.trailing.equalTo(backgroundView)
            make.top.bottom.equalTo(borderView)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        if let options = skeletonOptions {
            setupSkeleton(options: options)
        }
    }

    @objc private func actionOnMore() {
        delegate?.stakingStateViewDidReceiveMoreAction(self)
    }

    @objc private func actionOnStatus() {
        delegate?.stakingStateViewDidReceiveStatusAction(self)
    }
}

extension StakingStateView {
    func setupSkeleton(options: StakingStateSkeletonOptions) {
        skeletonOptions = nil

        guard !options.isEmpty else {
            skeletonView?.removeFromSuperview()
            skeletonView = nil
            return
        }

        skeletonOptions = options

        let spaceSize = backgroundView.frame.size

        let skeletons = createSkeletons(for: spaceSize, options: options)

        let builder = Skrull(
            size: spaceSize,
            decorations: [],
            skeletons: skeletons
        )

        let currentSkeletonView: SkrullableView?

        if let skeletonView = skeletonView {
            currentSkeletonView = skeletonView
            builder.updateSkeletons(in: skeletonView)
        } else {
            let view = builder
                .fillSkeletonStart(R.color.colorSkeletonStart()!)
                .fillSkeletonEnd(color: R.color.colorSkeletonEnd()!)
                .build()
            view.autoresizingMask = []
            insertSubview(view, aboveSubview: backgroundView)

            currentSkeletonView = view
            skeletonView = view

            view.startSkrulling()
        }

        currentSkeletonView?.frame = CGRect(origin: .zero, size: spaceSize)
    }

    private func createSkeletons(
        for spaceSize: CGSize,
        options: StakingStateSkeletonOptions
    ) -> [Skeletonable] {
        guard spaceSize.width > 0.0, spaceSize.height > 0.0 else {
            return []
        }

        var skeletons: [Skeletonable] = []

        if options.contains(.stake) {
            let stakeSkeletons = createMultilineSkeleton(
                under: stakeTitleLabel,
                containerView: backgroundView,
                spaceSize: spaceSize,
                hasSmall: options.contains(.price)
            )

            skeletons.append(contentsOf: stakeSkeletons)
        }

        if options.contains(.rewards) {
            let rewardSkeletons = createMultilineSkeleton(
                under: rewardTitleLabel,
                containerView: backgroundView,
                spaceSize: spaceSize,
                hasSmall: options.contains(.price)
            )

            skeletons.append(contentsOf: rewardSkeletons)
        }

        if options.contains(.status) {
            let statusSkeletons = createStatusSkeleton(for: spaceSize)
            skeletons.append(contentsOf: statusSkeletons)
        }

        return skeletons
    }

    private func createStatusSkeleton(for spaceSize: CGSize) -> [Skeletonable] {
        let bigRowSize = UIConstants.skeletonBigRowSize
        let targetFrame = borderView.convert(borderView.bounds, to: self)

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

        return [
            SingleSkeleton(
                position: spaceSize.skrullMap(point: positionLeft),
                size: mappedSize
            ).round(),
            SingleSkeleton(
                position: spaceSize.skrullMap(point: positionRight),
                size: mappedSize
            ).round()
        ]
    }

    private func createMultilineSkeleton(
        under view: UIView,
        containerView: UIView,
        spaceSize: CGSize,
        hasSmall: Bool
    ) -> [Skeletonable] {
        let topInset: CGFloat = 7.0
        let verticalSpacing: CGFloat = 10.0

        var skeletons: [Skeletonable] = [
            SingleSkeleton.createRow(
                under: view,
                containerView: containerView,
                spaceSize: spaceSize,
                offset: CGPoint(x: 0.0, y: topInset),
                size: UIConstants.skeletonBigRowSize
            )
        ]

        if hasSmall {
            let yOffset = topInset + UIConstants.skeletonBigRowSize.height + verticalSpacing
            skeletons.append(
                SingleSkeleton.createRow(
                    under: view,
                    containerView: containerView,
                    spaceSize: spaceSize,
                    offset: CGPoint(x: 0.0, y: yOffset),
                    size: UIConstants.skeletonSmallRowSize
                )
            )
        }

        return skeletons
    }
}

extension StakingStateView {
    private static func createButton() -> TriangularedButton {
        let button = TriangularedButton()
        button.triangularedView?.cornerCut = .bottomRight
        button.triangularedView?.fillColor = .clear
        button.triangularedView?.highlightedFillColor = R.color.colorHighlightedPink()!
        button.triangularedView?.shadowOpacity = 0.0
        return button
    }

    private static func createMultiValueView() -> MultiValueView {
        let view = MultiValueView()
        view.valueTop.font = .p0Digits
        view.valueTop.textColor = R.color.colorWhite()
        view.valueTop.textAlignment = .left
        view.valueBottom.font = .p2Paragraph
        view.valueBottom.textColor = R.color.colorTransparentText()
        view.valueBottom.textAlignment = .left
        view.spacing = 4.0
        return view
    }

    private static func createStackView() -> UIStackView {
        let view = UIStackView()
        view.axis = .vertical
        view.alignment = .leading
        view.spacing = 4.0
        return view
    }
}

extension StakingStateView: SkeletonLoadable {
    func didDisappearSkeleton() {
        skeletonView?.stopSkrulling()
    }

    func didAppearSkeleton() {
        skeletonView?.startSkrulling()
    }

    func didUpdateSkeletonLayout() {
        guard let skeletonOptions = skeletonOptions else {
            return
        }

        setupSkeleton(options: skeletonOptions)
    }
}
