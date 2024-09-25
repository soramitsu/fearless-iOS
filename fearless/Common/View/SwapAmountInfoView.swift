import UIKit

final class SwapAmountInfoView: UIView {
    private let swapFromDirectionView = SwapDirectionView()

    private let arrowIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.iconSmallArrowDown()
        imageView.contentMode = .center
        return imageView
    }()

    private let swapToDirectionView = SwapDirectionView()

    private let stackView = UIFactory.default.createVerticalStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: SwapAmountInfoViewModel) {
        swapFromDirectionView.bind(viewModel: viewModel.swapFromViewModel)
        swapToDirectionView.bind(viewModel: viewModel.swapToViewModel)
    }

    private func setupLayout() {
        addSubview(stackView)
        stackView.addArrangedSubview(swapFromDirectionView)
        stackView.addArrangedSubview(arrowIconView)
        stackView.addArrangedSubview(swapToDirectionView)

        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
