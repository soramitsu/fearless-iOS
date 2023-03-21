import Foundation
import UIKit

public final class PoolView: UIControl, Molecule {
    
    public let sora: PoolViewConfiguration<PoolView>
    
    // MARK: - UI
    
    let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.spacing = 0
        stackView.isUserInteractionEnabled = false
        return stackView
    }()
    
    public let favoriteButton: ImageButton = {
        let view = ImageButton(size: CGSize(width: 40, height: 40))
        view.isHidden = true
        return view
    }()
    
    let currenciesView: SoramitsuView = {
        let view = SoramitsuView()
        view.heightAnchor.constraint(equalToConstant: 40).isActive = true
        view.widthAnchor.constraint(equalToConstant: 64).isActive = true
        view.sora.isUserInteractionEnabled = false
        return view
    }()
    
    let firstCurrencyImageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: 40).isActive = true
        view.widthAnchor.constraint(equalToConstant: 40).isActive = true
        view.isUserInteractionEnabled = false
        return view
    }()
    
    let secondCurrencyImageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: 40).isActive = true
        view.widthAnchor.constraint(equalToConstant: 40).isActive = true
        view.isUserInteractionEnabled = false
        return view
    }()
    
    let rewardViewContainter: SoramitsuView = {
        let view = SoramitsuView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.sora.backgroundColor = .bgPage
        view.sora.cornerRadius = .circle
        view.sora.isUserInteractionEnabled = false
        view.heightAnchor.constraint(equalToConstant: 22).isActive = true
        view.widthAnchor.constraint(equalToConstant: 22).isActive = true
        return view
    }()
    
    let rewardImageView: SoramitsuImageView = {
        let view = SoramitsuImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: 18).isActive = true
        view.widthAnchor.constraint(equalToConstant: 18).isActive = true
        view.sora.cornerRadius = .circle
        view.sora.borderColor = .bgPage
        view.sora.isUserInteractionEnabled = false
        view.sora.backgroundColor = .additionalPolkaswap
        return view
    }()
    
    let infoStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 4
        stackView.isUserInteractionEnabled = false
        stackView.distribution = .fillEqually
        return stackView
    }()
    
    let titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textM
        label.sora.textColor = .fgPrimary
        label.sora.isUserInteractionEnabled = false
        return label
    }()
    
    let subtitleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textBoldXS
        label.sora.textColor = .fgSecondary
        label.sora.isHidden = true
        label.sora.isUserInteractionEnabled = false
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }()
    
    let amountStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.distribution = .fillEqually
        stackView.spacing = 4
        stackView.isUserInteractionEnabled = false
        stackView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        stackView.setContentCompressionResistancePriority(.required, for: .horizontal)
        return stackView
    }()
    
    let amountUpLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textM
        label.sora.textColor = .fgPrimary
        label.sora.alignment = .right
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()
    
    let amountDownLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textBoldXS
        label.sora.textColor = .statusSuccess
        label.sora.alignment = .right
        label.sora.text = " "
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()
    
    let actionsStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.spacing = 4
        stackView.isHidden = true
        return stackView
    }()
    
    let dragDropImageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: 32).isActive = true
        view.widthAnchor.constraint(equalToConstant: 32).isActive = true
        view.isHidden = true
        return view
    }()
    
    init(style: SoramitsuStyle, mode: WalletViewMode = .view) {
        sora = PoolViewConfiguration(style: style, mode: mode)
        super.init(frame: .zero)
        sora.owner = self
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension PoolView {
    func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(stackView)
        
        currenciesView.addSubview(firstCurrencyImageView)
        rewardViewContainter.addSubviews(rewardImageView)
        
        currenciesView.addSubview(secondCurrencyImageView)
        currenciesView.addSubview(rewardViewContainter)
        
        infoStackView.addArrangedSubview(titleLabel)
        infoStackView.addArrangedSubview(subtitleLabel)
        
        amountStackView.addArrangedSubview(amountUpLabel)
        amountStackView.addArrangedSubview(amountDownLabel)
        
        actionsStackView.addArrangedSubview(dragDropImageView)
        
        stackView.addArrangedSubview(favoriteButton)
        stackView.setCustomSpacing(16, after: favoriteButton)
        stackView.addArrangedSubview(currenciesView)
        stackView.setCustomSpacing(8, after: currenciesView)
        stackView.addArrangedSubview(infoStackView)
        stackView.setCustomSpacing(8, after: infoStackView)
        stackView.addArrangedSubview(amountStackView)
        stackView.addArrangedSubview(actionsStackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            stackView.heightAnchor.constraint(equalToConstant: 40),
            
            firstCurrencyImageView.leadingAnchor.constraint(equalTo: currenciesView.leadingAnchor),
            firstCurrencyImageView.centerYAnchor.constraint(equalTo: currenciesView.centerYAnchor),
            firstCurrencyImageView.topAnchor.constraint(equalTo: currenciesView.topAnchor),
            secondCurrencyImageView.leadingAnchor.constraint(equalTo: firstCurrencyImageView.leadingAnchor, constant: 24),
            rewardImageView.trailingAnchor.constraint(equalTo: secondCurrencyImageView.trailingAnchor),
            rewardImageView.bottomAnchor.constraint(equalTo: secondCurrencyImageView.bottomAnchor),

            rewardViewContainter.centerXAnchor.constraint(equalTo: rewardImageView.centerXAnchor),
            rewardViewContainter.centerYAnchor.constraint(equalTo: rewardImageView.centerYAnchor)
        ])
    }
}

public extension PoolView {
    
    convenience init(mode: WalletViewMode = .view) {
        let sora = SoramitsuUI.shared
        self.init(style: sora.style, mode: mode)
    }
}
