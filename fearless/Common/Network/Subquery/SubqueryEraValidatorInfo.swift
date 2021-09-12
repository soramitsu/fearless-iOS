import FearlessUtils

struct SubqueryEraValidatorInfo {
    let address: AccountAddress
    let era: EraIndex

    init?(from json: JSON) {
        guard
            let era = json.era?.unsignedIntValue,
            let address = json.address?.stringValue
        else { return nil }

        self.era = EraIndex(era)
        self.address = address
    }
}
