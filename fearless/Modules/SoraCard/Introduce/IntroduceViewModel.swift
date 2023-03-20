final class IntroduceViewModel {
    let data: SCKYCUserDataModel

    init(data: SCKYCUserDataModel) {
        self.data = data
    }

    var isContinueEnabled: Bool {
        !(data.name.isEmpty || data.lastname.isEmpty)
    }
}
