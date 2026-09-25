import Foundation
import BigInt

/*
 Source: https://github.com/ton-blockchain/ton/blob/24dc184a2ea67f9c47042b4104bbb4d82289fac1/crypto/block/block.tlb#L151
 message$_ {X:Type} info:CommonMsgInfoRelaxed
                    init:(Maybe (Either StateInit ^StateInit))
                    body:(Either X ^X) = MessageRelaxed X;
 */

public struct MessageRelaxed: CellCodable {
    public let info: CommonMsgInfoRelaxed
    public let stateInit: StateInit?
    public let body: Cell
    
    public static func loadFrom(slice: Slice) throws -> MessageRelaxed {
        let info = try CommonMsgInfoRelaxed.loadFrom(slice: slice)
            
        var stateInit: StateInit? = nil
        if try slice.loadBoolean() {
            if !(try slice.loadBoolean()) {
                stateInit = try StateInit.loadFrom(slice: slice)
            } else {
                stateInit = try StateInit.loadFrom(slice: try slice.loadRef().beginParse())
            }
        }
        
        var body: Cell
        if try slice.loadBoolean() {
            body = try slice.loadRef()
        } else {
            body = try slice.loadRemainder()
        }
        
        return MessageRelaxed(info: info, stateInit: stateInit, body: body)
    }
    
    public func storeTo(builder: Builder) throws {
        try builder.store(info)
        
        if let stateInit {
            try builder.store(bit: 2)
            let initCell = try Builder().store(stateInit)
            
            // check if we fit the cell inline with 2 bits for the stateinit and the body
            if let space = builder.fit(initCell.metrics), space.bitsCount >= 2 {
                try builder.store(bit: 0)
                try builder.store(initCell)
            } else {
                try builder.store(bit: 1)
                try builder.store(ref:initCell)
            }
        } else {
            try builder.store(bit: 0)
        }
        
        if let space = builder.fit(body.metrics), space.bitsCount >= 1 {
            try builder.store(bit: 0)
            try builder.store(body.toBuilder())
        } else {
            try builder.store(bit: 1)
            try builder.store(ref: body)
        }
    }
    
    public static func `internal`(to: Address, value: BigUInt, bounce: Bool = true, stateInit: StateInit? = nil, body: Cell = .empty) -> MessageRelaxed {
        return MessageRelaxed(
            info: .internalInfo(
                info:
                    CommonMsgInfoRelaxedInternal(
                        ihrDisabled: true,
                        bounce: bounce,
                        bounced: false,
                        src: .none,
                        dest: to,
                        value: CurrencyCollection(coins: Coins(value)),
                        ihrFee: Coins(0),
                        forwardFee: Coins(0),
                        createdLt: 0,
                        createdAt: 0
                    )
            ),
            stateInit: stateInit,
            body: body
        )
    }
    public static func `internal`(to: Address, value: BigUInt, bounce: Bool = true, stateInit: StateInit? = nil, textPayload: String) throws -> MessageRelaxed {
        let body = try Builder().store(int: 0, bits: 32).writeSnakeData(Data(textPayload.utf8)).endCell()
        return .internal(to: to, value: value, bounce: bounce, stateInit: stateInit, body: body)
    }
}
