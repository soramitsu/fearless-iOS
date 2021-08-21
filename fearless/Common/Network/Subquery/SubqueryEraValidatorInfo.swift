import FearlessUtils

struct SubqueryEraValidatorInfo {
    let address: String
    let era: EraIndex
    let total: String
    let own: String
    let others: [SubqueryIndividualExposure]

    init?(from json: JSON) {
        guard
            let era = json.era?.unsignedIntValue,
            let address = json.address?.stringValue,
            let total = json.total?.stringValue,
            let own = json.own?.stringValue,
            let others = json.others?.arrayValue?.compactMap({ SubqueryIndividualExposure(from: $0) })
        else { return nil }

        self.era = EraIndex(era)
        self.address = address
        self.total = total
        self.own = own
        self.others = others
    }
}
