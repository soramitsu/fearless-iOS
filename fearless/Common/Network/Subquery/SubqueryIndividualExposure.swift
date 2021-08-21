import FearlessUtils

struct SubqueryIndividualExposure {
    let who: String
    let value: String

    init?(from json: JSON) {
        guard
            let who = json.who?.stringValue,
            let value = json.value?.stringValue
        else { return nil }
        self.who = who
        self.value = value
    }
}
