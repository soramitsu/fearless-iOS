import UIKit

private final class WordColumnView: UIView {
    private var indexes: [UILabel] = []
    private var words: [UILabel] = []

    var maximumWidth: CGFloat? {
        didSet {
            guard maximumWidth != oldValue else { return }
            applyWordStyle(to: words)
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    var horizontalSpacing: CGFloat = 16.0 {
        didSet {
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    var verticalSpacing: CGFloat = 2.0 {
        didSet {
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    var indexTitleColor: UIColor = .gray {
        didSet {
            applyIndexStyle(to: indexes)
        }
    }

    var indexFont: UIFont = .preferredFont(forTextStyle: .caption1) {
        didSet {
            applyIndexStyle(to: indexes)

            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    var wordTitleColor: UIColor = R.color.colorWhite()! {
        didSet {
            applyWordStyle(to: words)
        }
    }

    var wordFont: UIFont = .preferredFont(forTextStyle: .caption1) {
        didSet {
            applyWordStyle(to: words)

            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    override var intrinsicContentSize: CGSize {
        guard !words.isEmpty else { return .zero }
        let indexWidth = indexes.map { $0.intrinsicContentSize.width }.max() ?? 0
        let available = maximumWidth.map { max(1, $0 - indexWidth - horizontalSpacing) } ?? .greatestFiniteMagnitude
        var width: CGFloat = 0
        var height: CGFloat = 0
        for (index, word) in words.enumerated() {
            let size = word.sizeThatFits(CGSize(width: available, height: .greatestFiniteMagnitude))
            width = max(width, size.width)
            height += max(size.height, indexes[index].intrinsicContentSize.height)
        }
        return CGSize(
            width: indexWidth + horizontalSpacing + width,
            height: height + CGFloat(words.count - 1) * verticalSpacing
        )
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let indexWidth = indexes.map { $0.intrinsicContentSize.width }.max() ?? 0
        let available = maximumWidth.map { max(1, $0 - indexWidth - horizontalSpacing) } ?? .greatestFiniteMagnitude
        var offset: CGFloat = 0
        for (index, word) in words.enumerated() {
            let indexLabel = indexes[index]
            let wordSize = word.sizeThatFits(CGSize(width: available, height: .greatestFiniteMagnitude))
            let indexSize = indexLabel.intrinsicContentSize
            let height = max(wordSize.height, indexSize.height)
            indexLabel.frame = CGRect(
                x: 0,
                y: offset + (height - indexSize.height) / 2,
                width: indexSize.width,
                height: indexSize.height
            )
            word.frame = CGRect(
                x: indexWidth + horizontalSpacing,
                y: offset + (height - wordSize.height) / 2,
                width: wordSize.width,
                height: wordSize.height
            )
            offset += height + verticalSpacing
        }
    }

    func bind(words: [String], starting index: Int) {
        setupColumn(count: words.count)

        for (wordIndex, word) in words.enumerated() {
            self.words[wordIndex].text = word
            indexes[wordIndex].text = String(index + wordIndex)
        }

        invalidateIntrinsicContentSize()

        setNeedsLayout()
    }

    // MARK: Private

    func setupColumn(count: Int) {
        if words.count < count {
            let newIndexes: [UILabel] = (0 ..< (count - words.count)).map { _ in UILabel() }
            let newWords: [UILabel] = (0 ..< (count - words.count)).map { _ in UILabel() }

            applyIndexStyle(to: newIndexes)
            applyWordStyle(to: newWords)

            newIndexes.forEach { addSubview($0) }
            newWords.forEach { addSubview($0) }

            indexes.append(contentsOf: newIndexes)
            words.append(contentsOf: newWords)
        } else if words.count > count {
            let removedCount = words.count - count
            let removedIndexes = indexes.suffix(removedCount)
            let removedWords = words.suffix(removedCount)

            removedIndexes.forEach { $0.removeFromSuperview() }
            removedWords.forEach { $0.removeFromSuperview() }
            indexes.removeLast(removedCount)
            words.removeLast(removedCount)
        }
    }

    func applyIndexStyle(to list: [UILabel]) {
        list.forEach { label in
            label.textColor = indexTitleColor
            label.font = indexFont
        }
    }

    func applyWordStyle(to list: [UILabel]) {
        list.forEach { label in
            label.textColor = wordTitleColor
            label.font = wordFont
            label.numberOfLines = maximumWidth == nil ? 1 : 0
            label.lineBreakMode = .byCharWrapping
        }
    }
}

final class MnemonicDisplayView: UIView {
    var adaptsToAvailableWidth = false {
        didSet {
            guard adaptsToAvailableWidth != oldValue else { return }
            if !adaptsToAvailableWidth {
                allColumns.forEach { $0.maximumWidth = nil }
                if !boundWords.isEmpty { bindColumns(count: requestedColumns) }
            }
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    private var boundWords: [String] = []
    private var requestedColumns = 1
    private var measuredHeight: CGFloat = 0

    var columnsSpacing: CGFloat = 50.0 {
        didSet {
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    var horizontalSpacingInColumn: CGFloat {
        get {
            mainColumn.horizontalSpacing
        }

        set {
            mainColumn.horizontalSpacing = newValue

            otherColumns.forEach { $0.horizontalSpacing = newValue }

            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    var verticalSpacingInColumn: CGFloat {
        get {
            mainColumn.verticalSpacing
        }

        set {
            allColumns.forEach { $0.verticalSpacing = newValue }

            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    var indexTitleColorInColumn: UIColor {
        get {
            mainColumn.indexTitleColor
        }

        set {
            allColumns.forEach { $0.indexTitleColor = newValue }
        }
    }

    var indexFontInColumn: UIFont {
        get {
            mainColumn.indexFont
        }

        set {
            allColumns.forEach { $0.indexFont = newValue }

            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    var wordTitleColorInColumn: UIColor {
        get {
            mainColumn.wordTitleColor
        }

        set {
            allColumns.forEach { $0.wordTitleColor = newValue }
        }
    }

    var wordFontInColumn: UIFont {
        get {
            mainColumn.wordFont
        }

        set {
            allColumns.forEach { $0.wordFont = newValue }

            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    private var mainColumn = WordColumnView()
    private var otherColumns: [WordColumnView] = []

    private var allColumns: [WordColumnView] {
        [mainColumn] + otherColumns
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        configure()
    }

    override var intrinsicContentSize: CGSize {
        let columnsSize = allColumns.reduce(CGSize.zero) { result, column in
            let columnSize = column.intrinsicContentSize

            return CGSize(
                width: result.width + columnSize.width,
                height: max(columnSize.height, result.height)
            )
        }

        return CGSize(
            width: columnsSize.width + CGFloat(allColumns.count - 1) * columnsSpacing,
            height: columnsSize.height
        )
    }

    override func layoutSubviews() {
        if adaptsToAvailableWidth, !boundWords.isEmpty, bounds.width > 0 {
            let count = fittingColumnCount()
            if count != allColumns.count { bindColumns(count: count) }
            let width = max(1, (bounds.width - CGFloat(count - 1) * columnsSpacing) / CGFloat(count))
            allColumns.forEach { $0.maximumWidth = width }
        }
        super.layoutSubviews()

        let totalSize = intrinsicContentSize
        if measuredHeight != totalSize.height {
            measuredHeight = totalSize.height
            invalidateIntrinsicContentSize()
        }

        var offset: CGFloat = bounds.size.width / 2.0 - totalSize.width / 2.0

        for column in allColumns {
            let columnSize = column.intrinsicContentSize
            column.frame = CGRect(
                x: offset,
                y: bounds.height / 2.0 - columnSize.height / 2.0,
                width: columnSize.width,
                height: columnSize.height
            )
            offset += columnSize.width + columnsSpacing
        }
    }

    func bind(words: [String], columnsCount: Int) {
        defer {
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }

        guard !words.isEmpty, columnsCount > 0, words.count % columnsCount == 0 else {
            boundWords = []
            requestedColumns = 1
            setupColumns(count: 1)
            mainColumn.bind(words: [], starting: 1)
            return
        }

        boundWords = words
        requestedColumns = columnsCount
        bindColumns(count: fittingColumnCount())
    }

    private func fittingColumnCount() -> Int {
        guard adaptsToAvailableWidth, bounds.width > 0 else { return requestedColumns }
        for count in stride(from: requestedColumns, through: 1, by: -1) where boundWords.count % count == 0 {
            let rows = boundWords.count / count
            var width = CGFloat(count - 1) * columnsSpacing
            for column in 0 ..< count {
                let range = (column * rows) ..< ((column + 1) * rows)
                let wordWidth = range
                    .map { (boundWords[$0] as NSString).size(withAttributes: [.font: mainColumn.wordFont]).width }
                    .max() ?? 0
                let indexWidth = range
                    .map { (String($0 + 1) as NSString).size(withAttributes: [.font: mainColumn.indexFont]).width }
                    .max() ?? 0
                width += ceil(wordWidth) + ceil(indexWidth) + mainColumn.horizontalSpacing
            }
            if width <= bounds.width { return count }
        }
        return 1
    }

    private func bindColumns(count: Int) {
        let rows = boundWords.count / count
        setupColumns(count: count)
        for column in 0 ..< count {
            let start = column * rows
            allColumns[column].bind(words: Array(boundWords[start ..< (start + rows)]), starting: start + 1)
        }
    }

    // MARK: Private

    private func configure() {
        backgroundColor = .clear

        addSubview(mainColumn)
    }

    private func setupColumns(count: Int) {
        if allColumns.count < count {
            let newColumnsCount = count - allColumns.count
            let newColumns: [WordColumnView] = (0 ..< newColumnsCount).map { _ in
                let column = WordColumnView()
                column.horizontalSpacing = mainColumn.horizontalSpacing
                column.verticalSpacing = mainColumn.verticalSpacing
                column.indexTitleColor = mainColumn.indexTitleColor
                column.indexFont = mainColumn.indexFont
                column.wordTitleColor = mainColumn.wordTitleColor
                column.wordFont = mainColumn.wordFont
                return column
            }

            newColumns.forEach { addSubview($0) }

            otherColumns.append(contentsOf: newColumns)
        } else if allColumns.count > count {
            let removedCount = allColumns.count - count
            let removedColumns = otherColumns.suffix(removedCount)
            removedColumns.forEach { $0.removeFromSuperview() }
            otherColumns.removeLast(removedCount)
        }
    }
}
