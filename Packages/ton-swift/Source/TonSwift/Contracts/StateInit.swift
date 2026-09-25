import Foundation
import BigInt

// Source: https://github.com/ton-blockchain/ton/blob/24dc184a2ea67f9c47042b4104bbb4d82289fac1/crypto/block/block.tlb#L141
// _ split_depth:(Maybe (## 5)) special:(Maybe TickTock)
//  code:(Maybe ^Cell) data:(Maybe ^Cell)
//  library:(HashmapE 256 SimpleLib) = StateInit;

public struct StateInit: CellCodable {
    var splitDepth: UInt32?
    var special: TickTock?
    var code: Cell?
    var data: Cell?
    var libraries: [UInt256: SimpleLibrary]

    init(splitDepth: UInt32? = nil,
         special: TickTock? = nil,
         code: Cell? = nil,
         data: Cell? = nil,
         libraries: [UInt256: SimpleLibrary] = [:]) {
        self.splitDepth = splitDepth;
        self.special = special;
        self.code = code;
        self.data = data;
        self.libraries = libraries;
    }
    
    public func storeTo(builder: Builder) throws {
        if let splitDepth = self.splitDepth {
            try builder.store(bit: true)
            try builder.store(uint: UInt64(splitDepth), bits: 5)
        } else {
            try builder.store(bit: false)
        }
        
        if let ticktock = self.special {
            try builder.store(bit: true)
            try builder.store(ticktock)
        } else {
            try builder.store(bit: false)
        }
        
        try builder.storeMaybe(ref: self.code)
        try builder.storeMaybe(ref: self.data)
        try builder.store(self.libraries)
    }
    
    static public func loadFrom(slice: Slice) throws -> StateInit {
        let splitDepth: UInt32? = try slice.loadMaybe { s in
            UInt32(try s.loadUint(bits: 5))
        };

        let special: TickTock? = try slice.loadMaybe { s in
            try TickTock.loadFrom(slice: slice)
        };

        let code = try slice.loadMaybeRef()
        let data = try slice.loadMaybeRef()
        
        let libraries: [UInt256: SimpleLibrary] = try slice.loadType()
        
        return StateInit(splitDepth: splitDepth, special: special, code: code, data: data, libraries: libraries)
    }
}

// Source: https://github.com/ton-blockchain/ton/blob/24dc184a2ea67f9c47042b4104bbb4d82289fac1/crypto/block/block.tlb#L139
// tick_tock$_ tick:Bool tock:Bool = TickTock;

struct TickTock: CellCodable {
    var tick: Bool
    var tock: Bool
    
    func storeTo(builder: Builder) throws {
        try builder.store(bit: self.tick)
        try builder.store(bit: self.tock)
    }
    
    static func loadFrom(slice: Slice) throws -> TickTock {
        return TickTock(
            tick: try slice.loadBoolean(),
            tock: try slice.loadBoolean()
        )
    }
}

// Source: https://github.com/ton-blockchain/ton/blob/24dc184a2ea67f9c47042b4104bbb4d82289fac1/crypto/block/block.tlb#L145
// simple_lib$_ public:Bool root:^Cell = SimpleLib;

public struct SimpleLibrary: Hashable {
    var `public`: Bool
    var root: Cell
}

extension SimpleLibrary: CellCodable {
    public func storeTo(builder: Builder) throws {
        try builder.store(bit: self.public)
        try builder.store(ref: self.root)
    }
    public static func loadFrom(slice: Slice) throws -> SimpleLibrary {
        return Self(
            public: try slice.loadBoolean(),
            root: try slice.loadRef()
        )
    }
}
