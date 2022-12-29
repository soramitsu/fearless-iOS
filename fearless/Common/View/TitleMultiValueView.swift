import UIKit
import SoraUI

class TitleMultiValueView: UIView {
    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorLightGray()
        label.font = UIFont.p1Paragraph
        return label
    }()

    let valueTop: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .p1Paragraph
        label.textAlignment = .right
        return label
    }()

    let valueLabelsStack = UIFactory.default.createVerticalStackView()

    let valueBottom: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorGray()
        label.font = .p2Paragraph
        label.textAlignment = .right
        return label
    }()

    let borderView: BorderedContainerView = {
        let view = BorderedContainerView()
        view.backgroundColor = .clear
        view.borderType = .bottom
        view.strokeWidth = 1.0
        view.strokeColor = R.color.colorDarkGray()!
        return view
    }()

    let activityIndicator: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView()
        view.hidesWhenStopped = true
        view.style = .white
        return view
    }()

    var equalsLabelsWidth: Bool = false {
        didSet {
            if equalsLabelsWidth {
                valueTop.snp.makeConstraints { make in
                    make.width.equalTo(titleLabel.snp.width)
                }

                valueBottom.snp.makeConstraints { make in
                    make.width.equalTo(titleLabel.snp.width)
                }
            }
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

    func bind(viewModel: TitleMultiValueViewModel?) {
        if viewModel != nil {
            activityIndicator.stopAnimating()
        } else {
            activityIndicator.startAnimating()
        }

        valueTop.text = viewModel?.title
        valueBottom.text = viewModel?.subtitle

        valueTop.isHidden = viewModel?.title == nil
        valueBottom.isHidden = viewModel?.subtitle == nil
    }

    func bind(viewModel: BalanceViewModelProtocol?) {
        if viewModel != nil {
            activityIndicator.stopAnimating()
        } else {
            activityIndicator.startAnimating()
        }

        valueTop.text = viewModel?.amount
        valueBottom.text = viewModel?.price
    }

    func setupLayout() {
        addSubview(borderView)
        borderView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.top.bottom.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        addSubview(valueLabelsStack)
        valueLabelsStack.snp.makeConstraints { make in
            make.trailing.top.bottom.equalToSuperview()
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(8.0)
        }

        valueLabelsStack.addArrangedSubview(valueTop)
        valueLabelsStack.addArrangedSubview(valueBottom)

        addSubview(activityIndicator)
        activityIndicator.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalTo(valueTop.snp.trailing)
        }
    }
}
