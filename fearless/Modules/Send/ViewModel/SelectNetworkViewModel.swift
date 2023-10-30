struct SelectNetworkViewModel {
    let chainName: String
    let iconViewModel: ImageViewModelProtocol?
    let canEdit: Bool

    init(chainName: String, iconViewModel: ImageViewModelProtocol?, canEdit: Bool = true) {
        self.chainName = chainName
        self.iconViewModel = iconViewModel
        self.canEdit = canEdit
    }
}
