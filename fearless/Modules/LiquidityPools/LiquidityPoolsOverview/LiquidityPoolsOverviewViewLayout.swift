import UIKit

final class LiquidityPoolsOverviewViewLayout: UIView {
    let navigationBar: BaseNavigationBar = {
        let bar = BaseNavigationBar()
        bar.backgroundColor = R.color.colorBlack19()
        return bar
    }()

    let polkaswapImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.polkaswap()
        return imageView
    }()

    private let backgroundImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.image = R.image.backgroundImage()
        return imageView
    }()

    let scrollView = UIScrollView()
    let scrollViewBackgroundView = UIFactory.default.createVerticalStackView(spacing: 16)
    let userPoolsContainerView = TriangularedBlurView()
    let availablePoolsContainerView = TriangularedBlurView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        userPoolsContainerView.isHidden = true
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
        addSubview(navigationBar)
        addSubview(scrollView)
        scrollView.addSubview(scrollViewBackgroundView)
        scrollViewBackgroundView.addArrangedSubview(userPoolsContainerView)
        scrollViewBackgroundView.addArrangedSubview(availablePoolsContainerView)

        navigationBar.setCenterViews([polkaswapImageView])
    }

    private func setupConstraints() {
        backgroundImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        navigationBar.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview()
        }

        scrollView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalTo(navigationBar.snp.bottom)
        }

        scrollViewBackgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.height.equalTo(self)
        }

        userPoolsContainerView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
        }

        availablePoolsContainerView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
        }
    }
}
