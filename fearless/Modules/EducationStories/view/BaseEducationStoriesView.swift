import Foundation
import UIKit

protocol EducationSlideView: UIView {
    var title: String { get }
    var descriptionTitle: String { get }
    var image: UIImage? { get }
    var imageViewContentMode: ContentMode { get }
}

final class BaseEducationStoriesView: UIView {
    private enum Constants {
        static let touchAreaWidth: CGFloat = 80
    }

    // MARK: - UI

    private lazy var activeStoriesView = UIView()
    private lazy var storiesProgressView: EducationStoriesProgressView = {
        let view = EducationStoriesProgressView()
        view.delegate = self
        return view
    }()

    private let backgroundImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.storiesBackground()
        return imageView
    }()

    private let topCloseButton: UIButton = {
        let button = UIButton()
        button.setImage(R.image.iconClose(), for: .normal)
        return button
    }()

    private lazy var bottomCloseButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyEnabledStyle()
        button.isHidden = true
        button.imageWithTitleView?.title = R.string.localizable
            .storiesBottomCloseButton(preferredLanguages: locale?.rLanguages)
        return button
    }()

    // MARK: - Private properties

    private var stories: [EducationSlideView]?
    private var onClose: (() -> Void)?
    private var locale: Locale?

    // MARK: - Constructors

    func startShow(
        stories: [EducationSlideView],
        locale: Locale,
        onClose: @escaping () -> Void
    ) {
        self.stories = stories
        self.locale = locale
        self.onClose = onClose

        storiesProgressView.configure(segmentsCount: stories.count)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupGesturesRecognizers()
        setupLayout()
        topCloseButton.addTarget(self, action: #selector(onCloseTap), for: .touchUpInside)
        bottomCloseButton.addTarget(self, action: #selector(onCloseTap), for: .touchUpInside)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Private methods

    private func setupGesturesRecognizers() {
        let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(longPressed))
        addGestureRecognizer(longPressRecognizer)

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleGesture))
        tapGesture.delegate = self
        addGestureRecognizer(tapGesture)
    }

    private func setupLayout() {
        addSubview(backgroundImageView)
        backgroundImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        backgroundImageView.addSubview(storiesProgressView)
        storiesProgressView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide.snp.top)
            make.leading.trailing.equalToSuperview().inset(16)
        }

        addSubview(topCloseButton)
        topCloseButton.snp.makeConstraints { make in
            make.top.equalTo(storiesProgressView.snp.bottom).offset(18)
            make.leading.equalToSuperview().offset(16)
            make.width.height.equalTo(44)
        }

        backgroundImageView.addSubview(activeStoriesView)
        activeStoriesView.snp.makeConstraints { make in
            make.top.equalTo(topCloseButton.snp.bottom).offset(18)
            make.leading.trailing.bottom.equalToSuperview()
        }

        addSubview(bottomCloseButton)
        bottomCloseButton.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.actionHeight)
            make.leading.trailing.bottom.equalToSuperview().inset(16)
        }
    }

    @objc private func handleGesture(gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended else { return }
        let location = gesture.location(in: self)

        if location.x <= Constants.touchAreaWidth {
            storiesProgressView.back()
        } else if location.x >= (frame.size.width - Constants.touchAreaWidth) {
            storiesProgressView.skip()
        }
    }

    @objc private func longPressed(sender: UILongPressGestureRecognizer) {
        if sender.state == .began {
            storiesProgressView.pauseAnimation()
        }

        if sender.state == .ended {
            storiesProgressView.continueAnimation()
        }
    }

    @objc private func onCloseTap() {
        onClose?()
    }
}

// MARK: - StoriesProgressViewDelegate

extension BaseEducationStoriesView: EducationStoriesProgressViewDelegate {
    func storiesProgressViewChanged(index: Int) {
        guard let stories = stories else { return }
        let slide = stories[index]
        activeStoriesView.subviews.forEach { $0.removeFromSuperview() }
        activeStoriesView.addSubview(slide)
        slide.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        bottomCloseButton.isHidden = !(stories.endIndex - 1 == index)
    }

    func storiesProgressViewFinished() {
        onClose?()
    }
}

// MARK: - UIGestureRecognizerDelegate

extension BaseEducationStoriesView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        !(touch.view is UIControl)
    }
}
