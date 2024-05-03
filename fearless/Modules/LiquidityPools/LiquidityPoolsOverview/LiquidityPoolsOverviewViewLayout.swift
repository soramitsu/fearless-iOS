import UIKit

final class LiquidityPoolsOverviewViewLayout: UIView {
    private let backgroundImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.image = R.image.backgroundImage()
        return imageView
    }()

    let scrollView = UIScrollView()
    let scrollViewBackgroundView = UIView()
    let userPoolsContainerView = TriangularedBlurView()
    let availablePoolsContainerView = TriangularedBlurView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        drawSubviews()
        setupConstraints()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func addUserPoolsView(_ view: UIView) {
        userPoolsContainerView.addSubview(view)
        view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func addAvailablePoolsView(_ view: UIView) {
        availablePoolsContainerView.addSubview(view)
        view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func drawSubviews() {
        addSubview(backgroundImageView)
        addSubview(scrollView)
        scrollView.addSubview(scrollViewBackgroundView)
        scrollViewBackgroundView.addSubview(userPoolsContainerView)
        scrollViewBackgroundView.addSubview(availablePoolsContainerView)
    }

    private func setupConstraints() {
        backgroundImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        scrollViewBackgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.height.equalTo(self)
        }

        userPoolsContainerView.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview().inset(16)
        }

        availablePoolsContainerView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview().inset(16)
            make.top.equalTo(userPoolsContainerView.snp.bottom).offset(16)
        }
    }
}
