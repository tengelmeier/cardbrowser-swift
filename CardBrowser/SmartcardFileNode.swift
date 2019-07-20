//
//  SmartcardFileNode.swift
//  CardBrowser
//
//  Created by Thomas Engelmeier on 19.07.19.
//  Copyright © 2019 Thomas Engelmeier. All rights reserved.
//

import Foundation

enum NodeType : String {
    case card,
        application,
        elementaryFile,
        fileControlInformation,
        applicationInterchangeProfile,
        record,
        sdaRecord,
        tlv,
        unknown
}

struct SmartCardFileNode : Encodable {
    let name : String
    var tag : Any
    var nodeType: NodeType

    var children = [SmartCardFileNode]()

    init( _ name: String, type: NodeType, tag : Any ) {
        self.name = name
        self.tag = tag
        self.nodeType = type
    }

    enum CodingKeys: CodingKey {
      case type, aid, sfi, number, children, staticDataAuthentication, tag, length, description, value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        if let tlv = tag as? ASN1 {
            let key = tlv.tag.hexString()
            let value = tlv.value.hexString()

            try container.encode("tlv", forKey: .type)
            try container.encode(key, forKey: .tag)
            try container.encode(tlv.length, forKey: .length)
            try container.encode(value, forKey: .value)
            try container.encode(name , forKey: .description)
        } else {
            try container.encode(nodeType.rawValue, forKey: .type)

            let data = tag as? Data ?? Data()
            let number = tag as? UInt8 ?? 0

            switch nodeType {
                case .application:
                    try container.encode( data.hexString(), forKey: .aid)
            case .elementaryFile:
                try container.encode( number, forKey: .sfi)
            case .record:
                if !data.isEmpty {
                    try container.encode( name, forKey: .tag)
                    try container.encode( data.hexString(), forKey: .value)
                } else {
                    try container.encode( number, forKey: .number)
                }
            case .sdaRecord:
                if !data.isEmpty {
                    try container.encode( name, forKey: .tag)
                    try container.encode( data.hexString(), forKey: .value)
                } else {
                    try container.encode( number, forKey: .number)
                }
                try container.encode( true, forKey: .staticDataAuthentication)
            default:
                break
            }
        }

        if !children.isEmpty {
            try container.encode(children, forKey: .children)
        }
    }
}
