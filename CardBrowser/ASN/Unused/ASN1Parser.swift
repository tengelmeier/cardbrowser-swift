//
//  ASN1Parser.swift
//  CardExplorer
//
//  Created by Thomas Engelmeier on 13.07.19.
//  Copyright © 2019 Thomas Engelmeier. All rights reserved.
//

import Foundation

class ASN1Parser {

    private var tlv : ASN1.DER.TLV
    init?( _ data: Data ) {
        var localData = data
        do {
            tlv = try ASN1.DER.Decoder.parse(&localData)
            value = localData
        } catch let error {
            return nil
        }
    }

    init( tlv: ASN1.DER.TLV ) {
        self.tlv = tlv
        switch tlv {
        case .integer( let data ):
                value = data
            case .unknown( let data ):
                value = data
            case .objectIdentifier( let string ):
                preconditionFailure( "Can not handle objectIdentifier \(string)" )
            case .sequence( let tlvs ):
                 preconditionFailure( "Can not handle nested TLVs \(tlvs)" )
            default:
                break
        }
    }

    var tag : UInt8 {
        get { return tlv.tagIdentifier }
    }

    var value: Data?

    func find( tagIdentifier: Int ) -> ASN1Parser? {
        var result: ASN1Parser? // ASN1.DER.TLV? = nil
        switch tlv {
            case .sequence( let tlvs ):
                if let matchingTlv = tlvs.first(where:{ $0.tagIdentifier == tagIdentifier }) {
                    result = ASN1Parser( tlv: matchingTlv )
                }
            default:
                break
        }
        return result
    }
}
