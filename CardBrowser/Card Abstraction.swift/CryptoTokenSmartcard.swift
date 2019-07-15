//
//  CryptoTokenSmartcard.swift
//  CardExplorer
//
//  Created by Thomas Engelmeier on 15.07.19.
//  Copyright © 2019 Thomas Engelmeier. All rights reserved.
//

import Foundation
import CryptoTokenKit

class CryptoTokenSmartcard : CardInterface {

    init( _ card: TKSmartCard ) {
        self.card = card
    }
    let card: TKSmartCard

    // var ATR : String? { return card.ATR }

    func beginSession( _ completion : @escaping( _ success: Bool, _ error : Error? ) -> Void ) {
        card.beginSession(reply: completion )
    }

    func endSession() { card.endSession() }
    func transmit( _ apdu: APDUCommand ) -> APDUResponse {

        /*
         let semaphore = DispatchSemaphore(value: 0)

         asychApi.call() {
         semaphore.signal()
         }
         _ = semaphore.wait(wallTimeout: .distantFuture)
         */

        /*guard let card = card else {
         return APDUResponse( sw1: 0, sw2: 0, data: nil, error: TKError( TKError.badParameter ) )
         } */

        do {
            card.cla = apdu.instructionClass

            Swift.print( "-> \(apdu.description)" )
            let response = try card.send(ins: apdu.instructionCode, p1: apdu.p1, p2: apdu.p2, data: apdu.data, le: apdu.expectedResponseLength )
            let sw1 = UInt8(response.sw >> 8)
            let sw2 = UInt8(response.sw & 0xFF)
            let apduResponse = APDUResponse( sw1: sw1, sw2: sw2, data: response.response, error: nil )
            Swift.print( "<- \(apduResponse.description)" )
            return apduResponse
        } catch let error {
            Swift.print( "SC error: \(error)" )
            return APDUResponse( sw1: 0, sw2: 0, data: nil, error: error )
        }
    }
}
