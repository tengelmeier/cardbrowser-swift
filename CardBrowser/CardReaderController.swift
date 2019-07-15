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

    var currentSlot : TKSmartCardSlot? = nil {
        didSet {
            if currentSlot != oldValue {
                slotStateObserver?.invalidate()
                slotStateObserver = nil

                if let slot = currentSlot {
                    slotStateObserver = slot.observe( \TKSmartCardSlot.state ) {
                        slot, change in
                        if slot.state == .validCard {
                            self.readCardInfo()
                        }
                    }

                    if slot.state == .validCard {
                        self.readCardInfo()
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
            currentSlot = cm.slotNamed(readerName)
        }
    }

    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if let destination = segue.destinationController as? EMVContentController {
            cardController = destination

            // prevent a race condition - in viewDidLoad the subcontroller is missing
            
            slotObserver = cardManager?.observe( \TKSmartCardSlotManager.slotNames ) {
                change, newValue in
                self.reloadSlots()
            }
            self.reloadSlots()
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
                self.selectSlot( readerPopup! )
            }
        }
    }

    private func readCardInfo() {
        Swift.print( "\(#function)" )
        if let atr = currentSlot?.atr {

            Swift.print( "\(atr.historicalBytes.debugDescription) protocols:\(atr.protocols)" )
        }

        let title = self.currentSlot?.atr?.historicalBytes.hexString() ?? "No Card"
        DispatchQueue.main.async {
            self.view.window?.title = title
        }

        cardController?.representedObject = currentSlot?.makeSmartCard()
    }

}

