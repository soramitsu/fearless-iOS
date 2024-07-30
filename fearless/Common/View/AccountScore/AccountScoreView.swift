import UIKit
import SoraUI
import Cosmos

class AccountScoreView: UIView {
    private var viewModel: AccountScoreViewModel?

    private var skeletonView: SkrullableView?

    let starView: CosmosView = {
        let view = CosmosView()
        view.settings.totalStars = 1
        view.settings.starSize = 15
        view.settings.textMargin = 2
        view.settings.textFont = .h6Title
        view.settings.passTouchesToSuperview = false
        view.settings.fillMode = .precise
        view.settings.updateOnTouch = false
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubviews()
        setupConstraints()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: AccountScoreViewModel?) {
        if viewModel?.scoringEnabled == false {
            isHidden = true
            return
        }

        if viewModel?.address.starts(with: "0x") != true {
            isHidden = false
            bindEmptyViewModel()
            return
        }

        isHidden = false
        startLoadingIfNeeded()
        self.viewModel = viewModel
        viewModel?.setup(with: self)
    }

    func bind(score: Int, rate: AccountScoreRate) {
        stopLoadingIfNeeded()
        starView.text = "\(score)"

        if let color = rate.color {
            starView.settings.emptyBorderColor = color
            starView.settings.filledColor = color
            starView.settings.filledBorderColor = color
            starView.settings.textColor = color
        }

        switch rate {
        case .high:
            starView.rating = 5
        case .medium:
            starView.rating = 2.5
        case .low:
            starView.rating = 0
        }
    }

    func bindEmptyViewModel() {
        starView.text = "N/A"
        starView.rating = 0
        starView.settings.textFont = .p2Paragraph

        if let color = R.color.colorLightGray() {
            starView.settings.emptyBorderColor = color
            starView.settings.filledColor = color
            starView.settings.filledBorderColor = color
            starView.settings.textColor = color
        }
    }

    private func addSubviews() {
        isHidden = true
        addSubview(starView)
    }

    private func setupConstraints() {
        starView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalTo(15)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        didUpdateSkeletonLayout()
    }
}

extension AccountScoreView: SkeletonLoadable {
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

        starView.alpha = 0.0

        setupSkeleton()
    }

    func stopLoadingIfNeeded() {
        guard skeletonView != nil else {
            return
        }

        skeletonView?.stopSkrulling()
        skeletonView?.removeFromSuperview()
        skeletonView = nil

        starView.alpha = 1.0
    }

    private func setupSkeleton() {
        let spaceSize = CGSize(width: 32, height: 15)

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

        skeletonView.frame = CGRect(origin: CGPoint(x: 0, y: spaceSize.height / 2), size: spaceSize)
        skeletonView.autoresizingMask = []
        insertSubview(skeletonView, aboveSubview: self)

        skeletonView.startSkrulling()
    }

    private func createSkeletons(for spaceSize: CGSize) -> [Skeletonable] {
        [
            SingleSkeleton.createRow(
                spaceSize: spaceSize,
                position: CGPoint(x: 0, y: 0.5),
                size: CGSize(width: 32, height: 15)
            )
        ]
    }
}
