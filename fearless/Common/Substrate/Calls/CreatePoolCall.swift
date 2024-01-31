import Foundation
import SSFUtils
import BigInt

enum StateTogglerValue {
    case stateToggler(value: MultiAddress)
    case bouncer(value: MultiAddress)
}

struct CreatePoolCall: Codable {
    enum CodingKeys: String, CodingKey {
        case amount
        case root
        case nominator
        case stateToggler
        case bouncer
    }

    @StringCodable var amount: BigUInt
    let root: MultiAddress
    let nominator: MultiAddress
    let stateToggler: StateTogglerValue

    init(
        amount: BigUInt,
        root: MultiAddress,
        nominator: MultiAddress,
        stateToggler: StateTogglerValue
    ) {
        self.amount = amount
        self.root = root
        self.nominator = nominator
        self.stateToggler = stateToggler
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(amount, forKey: .amount)
        try container.encode(root, forKey: .root)
        try container.encode(nominator, forKey: .nominator)

        switch stateToggler {
        case let .stateToggler(value):
            try container.encode(value, forKey: .stateToggler)
        case let .bouncer(value):
            try container.encode(value, forKey: .bouncer)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        amount = try container.decode(StringScaleMapper<BigUInt>.self, forKey: .amount).value
        root = try container.decode(MultiAddress.self, forKey: .root)
        nominator = try container.decode(MultiAddress.self, forKey: .nominator)

        do {
            let stateTogglerValue = try container.decode(MultiAddress.self, forKey: .stateToggler)
            stateToggler = .stateToggler(value: stateTogglerValue)
        } catch {
            let bouncer = try container.decode(MultiAddress.self, forKey: .bouncer)
            stateToggler = .bouncer(value: bouncer)
        }
    }
}
