import UIKit

final class TradeRouteView: UIView {
    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .h6Title
        label.textColor = R.color.colorStrokeGray()
        return label
    }()
    
    let scrollView: UIScrollView = {
       let scrollView = UIScrollView()
//        scrollView.contentInset = .init(top: 0, left: 12, bottom: 0, right: 12)
        return scrollView
    }()
    let contentView = UIView()
    let stackView: UIStackView = {
        let stackView = UIFactory.default.createHorizontalStackView(spacing: 8)
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

    func bind(viewModels: [ImageMarkedLabelViewModel]?) {
        stackView.arrangedSubviews.forEach {
            stackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        guard let viewModels else {
            return
        }
        
        for (i, viewModel) in viewModels.enumerated() {
            let view = ImageMarkedLabel()
            stackView.addArrangedSubview(view)
            view.bind(viewModel: viewModel)
            
            if i != viewModels.count - 1 {
                let imageView = UIImageView(image: R.image.iconRoute())
                stackView.addArrangedSubview(imageView)
            }
        }
    }

    private func setupLayout() {
        addSubview(titleLabel)
        addSubview(contentView)
        contentView.addSubview(scrollView)
        scrollView.addSubview(stackView)

        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.centerY.equalToSuperview()
        }
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalToSuperview()
        }
        
        contentView.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel.snp.trailing).offset(8)
            make.trailing.equalToSuperview()
            make.centerY.equalToSuperview()
            make.height.equalTo(self)
        }
        
        stackView.snp.makeConstraints { make in
            make.trailing.greaterThanOrEqualTo(contentView).inset(2)
            make.top.bottom.leading.equalToSuperview()
            make.trailing.equalToSuperview()
            make.centerY.equalToSuperview()
        }
    }
}
