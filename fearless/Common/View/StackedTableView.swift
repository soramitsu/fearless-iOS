
import UIKit

final class StackedTableView: UIView {
    
    static let defaultColumnsCount: Int = 2
    
    private let verticalStackView = UIFactory.default.createVerticalStackView()
    private var rows: [UIStackView] = []
    
    private var columns: Int

    init(columns: Int = defaultColumnsCount) {
        self.columns = columns
        
        super.init(frame: .zero)
        
        setupLayout()
    }
    
    override init(frame: CGRect) {
        self.columns = StackedTableView.defaultColumnsCount
        
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
    
    func addView(view: UIView) {
        let rowStack = rows.last ?? UIFactory.default.createHorizontalStackView()
        
        if rowStack.arrangedSubviews.count < columns {
            rowStack.addArrangedSubview(view)
        } else {
            let newRowStack = UIFactory.default.createHorizontalStackView()
            newRowStack.addArrangedSubview(view)
            verticalStackView.addArrangedSubview(newRowStack)
        }
    }


}
