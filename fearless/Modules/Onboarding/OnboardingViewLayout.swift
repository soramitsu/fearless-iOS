import UIKit

final class OnboardingViewLayout: UIView {
    private let pageViewControllerContainer = UIView()

    let crossButton: UIButton = {
        let button = UIButton()
        button.setImage(R.image.iconClose(), for: .normal)
        return button
    }()

    let collectionView: UICollectionView = {
        let view = UICollectionView(frame: .zero, collectionViewLayout: DefaultFlowLayout())
        view.showsVerticalScrollIndicator = false
        view.showsHorizontalScrollIndicator = false
        view.backgroundColor = .clear
        view.decelerationRate = .fast
        view.registerClassForCell(OnboardingPageCell.self)
        return view
    }()

    let pageControl: UIPageControl = {
        let view = UIPageControl()
        view.pageIndicatorTintColor = R.color.colorWhite30()
        view.currentPageIndicatorTintColor = R.color.colorWhite75()
        view.isUserInteractionEnabled = false
        return view
    }()

    let segmentedControl = FWSegmentedControl()

    let nextButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyEnabledStyle()
        return button
    }()

    let skipButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyEnabledStyle()
        button.triangularedView?.fillColor = R.color.colorBlack1()!
        button.triangularedView?.highlightedFillColor = R.color.colorBlack1()!
        return button
    }()

    var locale: Locale = .current {
        didSet {
            applyLocalization()
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

    // MARK: - Private methods

    private func setupLayout() {
        addSubview(nextButton)
        addSubview(skipButton)

        skipButton.snp.makeConstraints { make in
            make.bottom.trailing.equalTo(safeAreaLayoutGuide).inset(UIConstants.bigOffset)
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.height.equalTo(UIConstants.actionHeight)
            make.top.equalTo(nextButton.snp.bottom).offset(UIConstants.defaultOffset)
        }

        nextButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        let stackContainer = UIFactory.default.createVerticalStackView(spacing: UIConstants.minimalOffset)
        addSubview(stackContainer)
        stackContainer.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(55)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(nextButton.snp.top).offset(-UIConstants.bigOffset)
        }

        stackContainer.addArrangedSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalToSuperview().offset(-UIConstants.hugeOffset)
        }

        stackContainer.addArrangedSubview(pageControl)
        pageControl.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
        }

        addSubview(crossButton)
        crossButton.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(32)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.size.equalTo(UIConstants.roundedCloseButtonSize)
        }
    }

    private func applyLocalization() {
        nextButton.imageWithTitleView?.title = R.string.localizable.commonNext(preferredLanguages: locale.rLanguages)
        skipButton.imageWithTitleView?.title = R.string.localizable.commonSkip(preferredLanguages: locale.rLanguages)
    }
}
