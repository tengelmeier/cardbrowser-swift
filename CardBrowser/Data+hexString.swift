//
//  Data+hexString.swift
//  CardExplorer
//
//  https://codereview.stackexchange.com/questions/135424/hex-string-to-bytes-nsdata
//

import Foundation

extension Data {

    // Convert 0 ... 9, a ... f, A ...F to their decimal value,
    // return nil for all other input characters
    fileprivate func decodeNibble(_ u: UInt16) -> UInt8? {
        switch(u) {
        case 0x30 ... 0x39:
            return UInt8(u - 0x30)
        case 0x41 ... 0x46:
            return UInt8(u - 0x41 + 10)
        case 0x61 ... 0x66:
            return UInt8(u - 0x61 + 10)
        default:
            return nil
        }
    }

    init?(fromHexString string: String) {
        var str = string
        if str.count%2 != 0 {
            // insert 0 to get even number of chars
            str.insert("0", at: str.startIndex)
        }

        let utf16 = str.utf16
        self.init(capacity: utf16.count/2)

        var i = utf16.startIndex
        while i != str.utf16.endIndex {
            guard let hi = decodeNibble(utf16[i]),
                let lo = decodeNibble(utf16[utf16.index(i, offsetBy: 1, limitedBy: utf16.endIndex)!]) else {
                    return nil
            }
            var value = hi << 4 + lo
            self.append(&value, count: 1)
            i = utf16.index(i, offsetBy: 2, limitedBy: utf16.endIndex)!
        }
    }
    
    private static let hexAlphabet = "0123456789abcdef".unicodeScalars.map { $0 }

    public func hexString( joinedBy: String = "" ) -> String {
        return String(self.reduce(into: "".unicodeScalars, {
            (result, value) in
            if !result.isEmpty {
                result.append( contentsOf:joinedBy.unicodeScalars )
            }
            result.append(Data.hexAlphabet[Int(value/16)])
            result.append(Data.hexAlphabet[Int(value%16)])
        }))
    }
}
