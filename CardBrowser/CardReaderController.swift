//
//  CardReaderController.swift
//  CardExplorer
//
//  Created by Thomas Engelmeier on 12.07.19.
//  Copyright © 2019 Thomas Engelmeier. All rights reserved.
//

import Cocoa
import CryptoTokenKit

class CardReaderController: NSViewController {

    let cardManager = TKSmartCardSlotManager.default

    @IBOutlet var readerPopup : NSPopUpButton!

    var cardController : NSViewController?
    var slotObserver : NSKeyValueObservation? = nil
    var slotStateObserver : NSKeyValueObservation? = nil
    // var lastSlotState : TKSmartCardSlot.State = .missing

    var currentCard : TKSmartCard? = nil {
        didSet {
            DispatchQueue.main.async {
                self.cardController?.representedObject = self.currentCard
            }
        }
    }

    var currentSlot : TKSmartCardSlot? = nil {
        didSet {
            if currentSlot != oldValue {
                slotStateObserver?.invalidate()
                slotStateObserver = nil
                currentCard = nil

                // The observer and usage of currentCard makes sure the card is only read once:
                // The state cycles valid ->(make card) -> probing -> valid

                if let slot = currentSlot {
                    slotStateObserver = slot.observe( \TKSmartCardSlot.state, options: [.initial] ) {
                        slot, change in
                        let state = slot.state
                        switch( state ) {
                            case .probing, .validCard:
                            if self.currentCard == nil {
                                self.readCardInfo()
                            }
                        default:
                            self.currentCard = nil

                        }
                    }
                }
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    deinit {
        slotObserver?.invalidate()
        slotObserver = nil

        slotStateObserver?.invalidate()
        slotStateObserver = nil
    }

    @IBAction func selectSlot( _ sender: Any ) {
        if let readerName = readerPopup.titleOfSelectedItem,
            let cm = cardManager {
            let slot = cm.slotNamed(readerName)
            currentSlot = slot
        }
    }

    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if let destination = segue.destinationController as? EMVContentController {
            cardController = destination

            // prevent a race condition - in viewDidLoad the subcontroller is missing
            
            slotObserver = cardManager?.observe( \TKSmartCardSlotManager.slotNames, options: [.initial] ) {
                change, newValue in
                DispatchQueue.main.async {
                    self.reloadSlots()
                }
            }

        }
    }

    private func reloadSlots() {
        readerPopup.removeAllItems()
        if let cm = cardManager {
            readerPopup.addItems(withTitles: cm.slotNames )

            if let slot = currentSlot {
            // reselect if its still present
                if let index = cm.slotNames.firstIndex(of: slot.name ) {
                    readerPopup.selectItem(at: index )
                } else {
                    currentSlot = nil
                }
            }

            // no slot? automatically select the first slot
            if currentSlot == nil,
                !cm.slotNames.isEmpty {
                readerPopup.selectItem(at: 0)
                self.selectSlot( self )
            }
        }
    }

    private func readCardInfo() {
        var title = "No Card"
        if let atr = currentSlot?.atr {
            Swift.print( "\(atr.historicalBytes.debugDescription) protocols:\(atr.protocols)" )
            currentCard = currentSlot?.makeSmartCard()
            title = atr.historicalBytes.hexString() 
        }


        DispatchQueue.main.async {
            self.view.window?.title = title
        }

    }

}

