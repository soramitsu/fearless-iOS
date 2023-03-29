
struct SoramitsuPlainTableViewDescriptor: SoramitsuElementDescriptor {

	func configure(_ element: SoramitsuTableView) {
		let footer = SoramitsuView(style: element.sora.style)
		footer.sora.useAutoresizingMask = true
		element.sora.tableViewFooter = footer
	}
}
