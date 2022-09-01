
import UIKit

final class StackedTableView: UIView {
    static let defaultColumnsCount: Int = 2

    private let verticalStackView: UIStackView = {
        let stackView = UIFactory.default.createVerticalStackView(spacing: UIConstants.defaultOffset)
        stackView.distribution = .fill
        return stackView
    }()

    private var rows: [UIStackView] = []

    private var columns: Int

    init(columns: Int = defaultColumnsCount) {
        self.columns = columns

        super.init(frame: .zero)

        setupLayout()
    }

    override init(frame: CGRect) {
        columns = StackedTableView.defaultColumnsCount

        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(verticalStackView)

        verticalStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func clear() {
        for subview in verticalStackView.arrangedSubviews {
            verticalStackView.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }

        rows.removeAll()
    }

    func addView(view: UIView) {
        if rows.last == nil {
            let stackView = createRowStackView()
            verticalStackView.addArrangedSubview(stackView)
            rows.append(stackView)
        }

        let rowStack = rows.last ?? createRowStackView()

        if rowStack.arrangedSubviews.count < columns {
            rowStack.addArrangedSubview(view)
        } else {
            let newRowStack = createRowStackView()
            newRowStack.addArrangedSubview(view)
            verticalStackView.addArrangedSubview(newRowStack)
            rows.append(newRowStack)
        }
    }

    private func createRowStackView() -> UIStackView {
        let rowStackView = UIFactory.default.createHorizontalStackView()
        rowStackView.distribution = .fillEqually
        return rowStackView
    }
}
