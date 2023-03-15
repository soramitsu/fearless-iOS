import CoreGraphics

public enum Corner {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
    
    var maskValue: CACornerMask {
        switch self {
        case .topLeft:     return CACornerMask.layerMinXMinYCorner
        case .topRight:    return CACornerMask.layerMaxXMinYCorner
        case .bottomLeft:  return CACornerMask.layerMinXMaxYCorner
        case .bottomRight: return CACornerMask.layerMaxXMaxYCorner
        }
    }
}


public enum CornerMask {
    case none
    case all
    case single(Corner)
    case top
    case bottom
    case left
    case right
    case mainDiagonal
    case secondaryDiagonal
    case three(except: Corner)
    
    var maskValue: CACornerMask {
        switch self {
        case .none: return []
        case .all: return [Corner.topLeft.maskValue,
                           Corner.topRight.maskValue,
                           Corner.bottomLeft.maskValue,
                           Corner.bottomRight.maskValue]
        case .single(let corner): return [corner.maskValue]
            
        case .top:               return [Corner.topLeft.maskValue, Corner.topRight.maskValue]
        case .bottom:            return [Corner.bottomLeft.maskValue, Corner.bottomRight.maskValue]
        case .left:              return [Corner.topLeft.maskValue, Corner.bottomLeft.maskValue]
        case .right:             return [Corner.topRight.maskValue, Corner.bottomRight.maskValue]
        case .mainDiagonal:      return [Corner.topLeft.maskValue, Corner.bottomRight.maskValue]
        case .secondaryDiagonal: return [Corner.topRight.maskValue, Corner.bottomLeft.maskValue]
        
        case .three(let except): do {
            switch except {
            case .topLeft:     return [Corner.topRight.maskValue,
                                       Corner.bottomLeft.maskValue,
                                       Corner.bottomRight.maskValue]
            case .topRight:    return [Corner.topLeft.maskValue,
                                       Corner.bottomLeft.maskValue,
                                       Corner.bottomRight.maskValue]
            case .bottomLeft:  return [Corner.topLeft.maskValue,
                                       Corner.topRight.maskValue,
                                       Corner.bottomRight.maskValue]
            case .bottomRight: return [Corner.topLeft.maskValue,
                                       Corner.topRight.maskValue,
                                       Corner.bottomLeft.maskValue]

            }
        }
        }
    }
}
