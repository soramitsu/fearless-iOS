import UIKit

final class CrossChainTransactionStatusView: UIView {
    private enum Constants {
        static let dotsCount: Int = 3
        static let dotSize: CGFloat = 6
    }

    var dotViews: [UIView] = []
    let statusLabel: UILabel = {
        let label = UILabel()
        label.font = .p3Paragraph
        label.textAlignment = .center
        return UILabel()
    }()

    var locale: Locale = .current

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        dotViews.forEach {
            $0.rounded()
        }
    }

    func bind(viewModel: CrossChainTransactionStatusViewModel) {
        dotViews.forEach { dotView in
            dotView.backgroundColor = viewModel.color
        }

        statusLabel.textColor = viewModel.color
        statusLabel.text = viewModel.title(for: locale)
    }

    private func setupLayout() {
        for i in 1 ... Constants.dotsCount {
            let view = UIView()
            addSubview(view)
            dotViews.append(view)
            view.snp.makeConstraints { make in
                make.size.equalTo(Constants.dotSize)
                make.centerY.equalToSuperview()
                switch i {
                case 1:
                    make.centerX.equalToSuperview().offset(-16)
                case 2:
                    make.centerX.equalToSuperview()
                case 3:
                    make.centerX.equalToSuperview().offset(16)
                default:
                    break
                }
            }
        }

        addSubview(statusLabel)
        statusLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().offset(8)
        }
    }
}
