import UIKit

enum AgreementParagraphViewType {
    case plain
    case numberListElement
    case numberListSubelement
}

class AgreementParagraphView: UIView {
    let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal

        return stackView
    }()

    let listCounterLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph

        return label
    }()

    let elementValueLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph

        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupView()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {}
}
