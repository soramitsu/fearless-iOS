import Foundation

/*
 Source: https://github.com/ton-blockchain/ton/blob/24dc184a2ea67f9c47042b4104bbb4d82289fac1/crypto/block/block.tlb#L147
 message$_ {X:Type} info:CommonMsgInfo
                    init:(Maybe (Either StateInit ^StateInit))
                    body:(Either X ^X) = Message X;
 */

public struct Message: CellCodable {
    public let info: CommonMsgInfo
    public let stateInit: StateInit?
    public let body: Cell
    
    public static func loadFrom(slice: Slice) throws -> Message {
        let info = try CommonMsgInfo.loadFrom(slice: slice)
        
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
        
        return Message(info: info, stateInit: stateInit, body: body)
    }
    
    public func storeTo(builder: Builder) throws {
        try builder.store(info)
        
        if let stateInit {
            try builder.store(bit: 1)
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
            try builder.store(bit:0)
        }
        
        if let space = builder.fit(body.metrics), space.bitsCount >= 1 {
            try builder.store(bit: 0)
            try builder.store(body.toBuilder())
        } else {
            try builder.store(bit: 1)
            try builder.store(ref:body)
        }
    }
    
    public static func external(to: Address, stateInit: StateInit?, body: Cell = .empty) -> Message {
        return Message(
            info: .externalInInfo(
                info: CommonMsgInfoExternalIn(
                    src: nil,
                    dest: to,
                    importFee: Coins(0)
                )
            ),
            stateInit: stateInit,
            body: body
        )
    }
    
}
