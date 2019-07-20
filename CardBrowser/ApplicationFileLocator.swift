//
//  ApplicationFileLocator.swift
//  CardExplorer
//
//  Created by Thomas Engelmeier on 13.07.19.
//  Copyright © 2019 Thomas Engelmeier. All rights reserved.
//

import Foundation

class ApplicationFileLocator {
    let data : [UInt8]

    init( data sourceData: Data ) {
        precondition( sourceData.count >= 4 )
        data = [UInt8](sourceData)
    }

    var SFI : UInt8 {
        return data[0] >> 3
    }

    var firstRecord : UInt8 {
        return data[1]
    }

    var lastRecord : UInt8 {
        return data[2]
    }

    var offlineRecords : UInt8 {
        return data[3]
    }
}
