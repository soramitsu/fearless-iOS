import UIKit

final class SwapDirectionView: UIView {
    private let balancePriceView = BalancePriceHorizontalView()
    private let chainView = IconDetailsView()
    private let stackView: UIStackView = {
        let stackView = UIFactory.default.createVerticalStackView()
        stackView.alignment = .center
        return stackView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: SwapDirectionViewModel) {
        balancePriceView.bind(balanceViewModel: viewModel.balanceViewModel)
        chainView.detailsLabel.text = viewModel.chainViewModel?.text
        viewModel.chainViewModel?.icon?.loadImage(on: chainView.imageView, targetSize: CGSize(width: 20, height: 20), animated: true)
    }

    // MARK: - Private

    private func setupLayout() {
        addSubview(stackView)
        stackView.addArrangedSubview(balancePriceView)
        stackView.addArrangedSubview(chainView)

        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
