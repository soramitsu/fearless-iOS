import UIKit
import SoraUI

class TitleMultiValueView: UIView {
    let contentStackView = UIFactory.default.createHorizontalStackView(spacing: 8)
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
    
    let infoButton: ExtendedTouchAreaButton = {
        let button = ExtendedTouchAreaButton()
        button.setImage(R.image.iconInfoFilled(), for: .normal)
        button.isHidden = true
        return button
    }()
    
    let titleStackView: UIStackView = {
        let stackView = UIFactory.default.createHorizontalStackView(spacing: 6)
        stackView.alignment = .center
        return stackView
    }()
    
    let detailsButton: ExtendedTouchAreaButton = {
        let button = ExtendedTouchAreaButton()
        button.setImage(R.image.iconDetails(), for: .normal)
        button.isHidden = true
        return button
    }()
    

    var selectHandler: (() -> Void)? {
        didSet {
            detailsButton.isHidden = selectHandler == nil
        }
    }
    
    var infoHandler: (() -> Void)? {
        didSet {
            infoButton.isHidden = infoHandler == nil
        }
    }

    private var skeletonView: SkrullableView?

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
    
    func update(topText: String?) {
        guard topText != nil else {
            startLoadingIfNeeded()
            return
        }

        stopLoadingIfNeeded()
        valueTop.text = topText
        valueBottom.isHidden = true
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
        addSubview(contentStackView)
        borderView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        contentStackView.addArrangedSubview(titleStackView)

        contentStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        titleStackView.addArrangedSubview(titleLabel)
        contentStackView.addArrangedSubview(valueLabelsStack)

        valueLabelsStack.addArrangedSubview(valueTop)
        valueLabelsStack.addArrangedSubview(valueBottom)
        
        
        titleStackView.addArrangedSubview(infoButton)
        infoButton.snp.makeConstraints { make in
            make.size.equalTo(12)
        }
        
        contentStackView.addArrangedSubview(detailsButton)
        
        infoButton.addTarget(self, action: #selector(handleTapInfoButton), for: .touchUpInside)
        detailsButton.addTarget(self, action: #selector(handleTapGesture), for: .touchUpInside)
    }

    @objc func handleTapInfoButton() {
        infoHandler?()
    }
    
    @objc func handleTapGesture() {
        selectHandler?()
    }

    func startLoadingIfNeeded() {
        guard skeletonView == nil else {
            return
        }

        valueTop.alpha = 0.0
        valueBottom.alpha = 0.0

        setupSkeleton()
    }

    func stopLoadingIfNeeded() {
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
