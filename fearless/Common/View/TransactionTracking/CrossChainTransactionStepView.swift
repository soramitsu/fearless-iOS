import UIKit

final class CrossChainTransactionStepView: UIView {
    private enum Constants {
        static let viewSize: CGFloat = 40
        static let cornerRadius: CGFloat = 20
    }

    let backgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = R.color.colorWhite8()
        return view
    }()

    let chainIconView = UIImageView()
    let statusIconView = UIImageView()
    let parentChainIconView = UIImageView()

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
        backgroundView.rounded()
    }

    func bind(viewModel: CrossChainTransactionStepViewModel) {
        viewModel.chainIconViewModel?.loadImage(on: chainIconView, targetSize: CGSize(width: 18, height: 18), animated: true)
        statusIconView.image = viewModel.statusIconImage
        viewModel.parentChainIconViewModel?.loadImage(on: parentChainIconView, targetSize: CGSize(width: 15, height: 15), animated: true)
    }

    private func setupLayout() {
        addSubview(backgroundView)
        addSubview(chainIconView)
        addSubview(statusIconView)
        addSubview(parentChainIconView)

        backgroundView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.edges.equalToSuperview()
            make.size.equalTo(Constants.viewSize)
        }

        chainIconView.snp.makeConstraints { make in
            make.center.equalTo(backgroundView.snp.center)
            make.size.equalTo(18)
        }

        statusIconView.snp.makeConstraints { make in
            make.leading.bottom.equalTo(backgroundView)
            make.size.equalTo(10)
        }

        parentChainIconView.snp.makeConstraints { make in
            make.size.equalTo(15)
            make.centerY.equalTo(statusIconView.snp.centerY)
            make.trailing.equalToSuperview().offset(2.5)
        }
    }
}
