//
//  APDUResponse.swift
//  CardExplorer
//
//  Created by Thomas Engelmeier on 13.07.19.
//  Copyright © 2019 Thomas Engelmeier. All rights reserved.
//

import Foundation

struct APDUResponse {
    var sw1: UInt8
    var sw2: UInt8
    var data: Data?
    var error: Error?

    var description : String {
        get {   let hexDescription = data?.hexString(joinedBy: " " ) ?? "-"
                return String( format: "sw1:%02x sw2:%02x %@", sw1,  sw2, hexDescription ) }
    }
}
