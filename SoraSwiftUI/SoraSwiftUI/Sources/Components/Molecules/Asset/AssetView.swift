import Foundation
import UIKit

public final class AssetView: UIView, Molecule {
    
    public let sora: AssetViewConfiguration<AssetView>
    
    // MARK: - UI
    
    public let stackView: UIStackView = {
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
    
    public let assetImageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: 40).isActive = true
        view.widthAnchor.constraint(equalToConstant: 40).isActive = true
        view.isUserInteractionEnabled = false
        return view
    }()
    
    public let infoStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 4
        stackView.isUserInteractionEnabled = false
        stackView.distribution = .fillEqually
        return stackView
    }()
    
    public let titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textM
        label.sora.textColor = .fgPrimary
        label.sora.isUserInteractionEnabled = false
        return label
    }()
    
    public let subtitleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textBoldXS
        label.sora.textColor = .fgSecondary
        label.sora.isHidden = true
        label.sora.isUserInteractionEnabled = false
        return label
    }()
    
    public let amountStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.distribution = .fillEqually
        stackView.spacing = 4
        stackView.isUserInteractionEnabled = false
        stackView.setContentCompressionResistancePriority(.required, for: .horizontal)
        return stackView
    }()
    
    public let amountUpLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textM
        label.sora.textColor = .fgPrimary
        label.sora.alignment = .right
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()
    
    public let amountDownLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textBoldXS
        label.sora.textColor = .statusSuccess
        label.sora.alignment = .right
        label.sora.text = " "
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()
    
    public let actionsStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.spacing = 4
        stackView.isHidden = true
        return stackView
    }()
    
    public let visibilityButton: ImageButton = {
        let view = ImageButton(size: CGSize(width: 32, height: 32))
        view.sora.isHidden = true
        return view
    }()
    
    public let dragDropImageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: 32).isActive = true
        view.widthAnchor.constraint(equalToConstant: 32).isActive = true
        view.isHidden = true
        return view
    }()
    
    public let tappableArea: SoramitsuControl = {
        let view = SoramitsuControl()
        view.sora.isHidden = true
        return view
    }()
    
    init(style: SoramitsuStyle, mode: WalletViewMode = .view) {
        sora = AssetViewConfiguration(style: style, mode: mode)
        super.init(frame: .zero)
        sora.owner = self
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension AssetView {
    func setup() {
        translatesAutoresizingMaskIntoConstraints = false

        addSubview(stackView)
        addSubview(tappableArea)
        
        infoStackView.addArrangedSubview(titleLabel)
        infoStackView.addArrangedSubview(subtitleLabel)
        
        amountStackView.addArrangedSubview(amountUpLabel)
        amountStackView.addArrangedSubview(amountDownLabel)
        
        actionsStackView.addArrangedSubview(visibilityButton)
        actionsStackView.addArrangedSubview(dragDropImageView)
        
        stackView.addArrangedSubview(favoriteButton)
        stackView.setCustomSpacing(16, after: favoriteButton)
        stackView.addArrangedSubview(assetImageView)
        stackView.setCustomSpacing(8, after: assetImageView)
        stackView.addArrangedSubview(infoStackView)
        stackView.setCustomSpacing(8, after: infoStackView)
        stackView.addArrangedSubview(amountStackView)
        stackView.addArrangedSubview(actionsStackView)

        NSLayoutConstraint.activate([
            tappableArea.leadingAnchor.constraint(equalTo: leadingAnchor),
            tappableArea.topAnchor.constraint(equalTo: topAnchor),
            tappableArea.centerXAnchor.constraint(equalTo: centerXAnchor),
            tappableArea.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            stackView.heightAnchor.constraint(equalToConstant: 40),
        ])
    }
}

public extension AssetView {
    
    convenience init(mode: WalletViewMode = .view) {
        let sora = SoramitsuUI.shared
        self.init(style: sora.style, mode: mode)
    }
}
