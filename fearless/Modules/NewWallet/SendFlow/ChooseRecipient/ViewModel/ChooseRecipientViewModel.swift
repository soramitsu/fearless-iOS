import FearlessUtils

struct ChooseRecipientViewModel {
    let address: String
    let icon: DrawableIcon?
    let isValid: Bool
}

struct ChooseRecipientTableViewModel {
    let results: [SearchPeopleTableCellViewModel]
}
