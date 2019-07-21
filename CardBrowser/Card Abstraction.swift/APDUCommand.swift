//
//  APDUCommand.swift
//  CardExplorer
//
//  Created by Thomas Engelmeier on 13.07.19.
//  Copyright © 2019 Thomas Engelmeier. All rights reserved.
//

import Foundation

// Abstraction for easier porting of the original EMVCardExplorer code and
// for unifying CoreNFC vs. SmartCardServices

class APDUCommand {
    init( instructionClass: UInt8, // CLA nstruction class - indicates the type of command, e.g. interindustry or proprietary
          instructionCode: UInt8, // Instruction code - indicates the specific command, e.g. "write data"
          p1Parameter: UInt8, // Instruction parameters for the command, e.g. offset into file at which to write the data
          p2Parameter: UInt8,
          data: Data?,
          expectedResponseLength: Int? ) {
        self.instructionClass = instructionClass
        self.instructionCode = instructionCode
        self.p1 = p1Parameter
        self.p2 = p2Parameter
        self.data = data
        self.expectedResponseLength = expectedResponseLength // Encodes the maximum number (Ne) of response bytes expected
    }

    init( _ instructionClass: UInt8,
          _ instructionCode: UInt8,
          _ p1Parameter: UInt8,
          _ p2Parameter: UInt8,
          _ data: Data?,
          _ expectedResponseLength: UInt8? ) {
        self.instructionClass = instructionClass
        self.instructionCode = instructionCode
        self.p1 = p1Parameter
        self.p2 = p2Parameter
        self.data = data
        self.expectedResponseLength = expectedResponseLength != nil ? Int( expectedResponseLength! ) : nil
    }

    var description : String {
        get {
            let dataBytes = data?.hexString(joinedBy: " " ) ?? ""
            return String( format:"%02X %02X %02X (%02X) %@", instructionCode, p1, p2, data?.count ?? 0, dataBytes ) }
    }
    
    let instructionClass: UInt8
    let instructionCode: UInt8
    let p1: UInt8
    let p2: UInt8
    let data: Data?
    let expectedResponseLength: Int?
}

