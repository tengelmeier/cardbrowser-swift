//
//  CardInterface.swift
//  CardExplorer
//
//  Created by Thomas Engelmeier on 15.07.19.
//  Copyright © 2019 Thomas Engelmeier. All rights reserved.
//

import Foundation
import CryptoTokenKit

protocol CardInterface : class {
    // var ATR : String? { get }

    func beginSession( _ completion : @escaping( Bool, Error? ) -> Void )
    func endSession()
    func transmit( _ apdu: APDUCommand ) -> APDUResponse
}
