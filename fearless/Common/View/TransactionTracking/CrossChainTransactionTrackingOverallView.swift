import UIKit

final class CrossChainTransactionTrackingOverallView: UIView {
    let stackView: UIStackView = {
        let stackView = UIFactory.default.createHorizontalStackView(spacing: 16)
        stackView.distribution = .equalSpacing
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

    func bind(viewModels: [Any]) {
        viewModels.forEach { viewModel in
            if let stepViewModel = viewModel as? CrossChainTransactionStepViewModel {
                let view = CrossChainTransactionStepView()
                stackView.addArrangedSubview(view)

                view.bind(viewModel: stepViewModel)
            }

            if let statusViewModel = viewModel as? CrossChainTransactionStatusViewModel {
                let view = CrossChainTransactionStatusView()
                stackView.addArrangedSubview(view)

                view.bind(viewModel: statusViewModel)
            }
        }
    }

    private func setupLayout() {
        addSubview(stackView)

        stackView.snp.makeConstraints { make in
            make.centerX.top.equalToSuperview()
        }
    }
}
