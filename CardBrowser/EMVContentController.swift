//
//  EMVContentController.swift
//  CardExplorer
//
//  Created by Thomas Engelmeier on 13.07.19.
//  Copyright © 2019 Thomas Engelmeier. All rights reserved.
//

import Foundation
import Cocoa
import CryptoTokenKit

class EMVContentController : NSViewController {

    override var representedObject: Any? {
        didSet {
            var newCard : CryptoTokenSmartcard? = nil
            if let card = representedObject as? TKSmartCard {
                if let oldCard = oldValue as? TKSmartCard,
                    oldCard == card {
                    return // prevent reset 
                }
                newCard = CryptoTokenSmartcard( card )
            }
            self.card = newCard
        }
    }
    
    @IBOutlet var treeView : NSOutlineView! = nil

    private var rootNode = SmartCardFileNode( "root", type: .card, tag: "-" )
    private var card : CryptoTokenSmartcard? {
        didSet {
            rootNode.children.removeAll()
            DispatchQueue.main.async {
                self.treeView.reloadData()
            }

            card?.beginSession{
                success, error in
                self.cardQueue.async {
                    var identifiers = self.knownApplicationIdentifiers
                    if let pse = self.readPaymentSystemEnvironments( identifiers: self.defaultPaymentSystemIdentifiers ) {
                        self.rootNode.children.append( pse.0 )
                        identifiers = pse.1
                    }

                    identifiers.forEach {
                        let identifier = $0
                        if let identifierData = Data( fromHexString: identifier ),
                            let appNode = self.readData( ofApplication: identifierData ) {
                            self.rootNode.children.append( appNode )
                        }
                    }

                    DispatchQueue.main.async {
                        self.treeView.reloadData()
                    }
                }
            }
        }
    }
    private let cardQueue = DispatchQueue( label:"CardReader" )

    let defaultPaymentSystemIdentifiers =
        ["2PAY.SYS.DDF01", // NFC use
         "1PAY.SYS.DDF01"] // Wired use

    let knownApplicationIdentifiers =
    [
     "A000000003",        // VISA
     "A0000000031010", // VISA Debit/Credit
     "A000000003101001",   // VISA Credit
     "A000000003101002", // VISA Debit
     "A0000000032010",// VISA Electron
     "A0000000033010",  // VISA Interlink
     "A0000000038010", // VISA Plus
     "A000000003999910", // VISA ATM

     "A0000000041010",      // Mastercard
     "A0000000048010",     // Cirrus
     "A0000000043060",      // Maestro
     "A0000000050001",     // Maestro UK
     "A00000002401",        // Self Service
     "A000000025",         // American Express
     "A000000025010104",    // American Express
     "A000000025010701",    // ExpressPay
     "A0000000291010",     // Link
     "B012345678",        // Maestro TEST

     "A0000000651010"     // JCB
    ]

    @IBAction func saveDocument( _ sender: Any ) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "CardContents.json"

        guard let window = self.view.window else {
            return
        }

        panel.beginSheetModal(for: window) {
            result in

            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted

            if result == .OK,
                let url = panel.url,
                let data = try? encoder.encode( self.rootNode )  {
                try? data.write(to: url, options: [.atomicWrite] )
            }
        }
    }

}

extension EMVContentController : NSMenuItemValidation {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector( saveDocument(_:) ) {
            return self.rootNode.children.count > 0
        }
        return false 
    }
}

// Smartcard handling:

extension EMVContentController {

    func readPaymentSystemEnvironments( identifiers: [String] ) -> (SmartCardFileNode, [String])? {
        for identifier in identifiers {
            if let pseResult = readPaymentSystemEnvironment( identifier ) {
                return pseResult
            } else {
                Swift.print( "No PSE identifier \(identifier)" )
            }
        }
        return nil
    }

    // Fails for my MC
    func readPaymentSystemEnvironment( _ identifier: String ) -> (SmartCardFileNode, [String])? {
        guard let pse = identifier.data(using: .ascii ),
          let card = card else {
            return nil
        }

        var apdu = APDUCommand( 0x00, 0xA4, 0x04, 0x00, pse, UInt8( pse.count ) )
        var response = card.transmit(apdu)

        // Get response nescesary
        if response.sw1 == 0x61
        {
            apdu = APDUCommand(0x00, 0xC0, 0x00, 0x00, Data(), response.sw2)
            response = card.transmit(apdu)
        }

        // PSE application read found ok
        if response.sw1 == 0x90,
            let data = response.data,
            let tlv = ASN1( data: data )
        {
            var applicationIdentifiers = [String]()

            var pseNode = SmartCardFileNode( "Application \(pse)", type: .application, tag: pse )

            var fciNode = SmartCardFileNode("File Control Information", type: .fileControlInformation, tag: "fci" )
            addRecordNodes( tlv, to: &fciNode)
            pseNode.children.append( fciNode )

            // let tlv = ASN1Parser( data )
            if let sfi : UInt8 = tlv.find( 0x88 )?.value[0] {

                var recordNumber : UInt8 = 0x01
                let p2 = ((sfi << 3) | 4)

                var efDirNode = SmartCardFileNode( String( format: "EF Directory - %02x", sfi), type: .elementaryFile ,tag: sfi)
                // var recordNumber = 0
                while (response.sw1 != 0x6A && response.sw2 != 0x83)
                {
                    if let parsedRecord = readRecord(recordNumber: recordNumber, length: p2 ) {
                        efDirNode.children.append( parsedRecord.0 )
                        let identifierStrings = parsedRecord.1.map{ $0.hexString() }
                        applicationIdentifiers.append( contentsOf: identifierStrings )
                    }

                    recordNumber += 1
                }

                pseNode.children.append(efDirNode)
                return (pseNode, applicationIdentifiers)
            }
        }
        return nil
    }

    func readRecord( recordNumber: UInt8, length: UInt8 ) -> (SmartCardFileNode, [Data])? {
        var applicationIdentifiers = [Data]()
        var apdu = APDUCommand(0x00, 0xB2, recordNumber, length, Data(), 0x00)

        guard let card = card else {
            return nil
        }

        var response = card.transmit(apdu)
        // Retry with correct length
        if response.sw1 == 0x6C
        {
            apdu = APDUCommand(0x00, 0xB2, recordNumber, length, Data(), response.sw2)
            response = card.transmit(apdu)
        }

        if response.sw1 == 0x61
        {
            apdu = APDUCommand(0x00, 0xC0, 0x00, 0x00, Data(), response.sw2)
            response = card.transmit(apdu)
        }

        if let data = response.data,
            let aef = ASN1( data: data )
        {
            var recordNode = SmartCardFileNode(String(format:"Record - %02x", recordNumber), type: .record, tag: recordNumber)

            // efDirNode.children.append(recordNode)
            addRecordNodes( aef, to: &recordNode)
            for appTemplate in aef
            {
                // Check we really have an Application Template
                if appTemplate.tag[0] == 0x61,
                    let identifier = appTemplate.find(0x4f)?.value
                {
                    applicationIdentifiers.append( identifier )
                }
            }

            return (recordNode, applicationIdentifiers)
        }
        return nil
    }

    func readData( ofApplication aid: Data ) -> SmartCardFileNode? {
        guard let card = card else {
            return nil
        }

        var applicationFileLocators = [ApplicationFileLocator]()

        // Select AID
        var apdu = APDUCommand(0x00, 0xA4, 0x04, 0x00, aid, 0 )
        var response = card.transmit(apdu)

        // Get response nescesary
        if (response.sw1 == 0x61)
        {
            apdu = APDUCommand(0x00, 0xC0, 0x00, 0x00, Data(), response.sw2)
            response = card.transmit(apdu)
        }

        // Application not found
        if (response.sw1 == 0x6A && response.sw2 == 0x82) {
            return nil
        }

        if response.sw1 == 0x90,
            let data = response.data
        {
            let aidString = aid.hexString(joinedBy: "" )

            var applicationNode = SmartCardFileNode( "Application \(aidString)", type: .application, tag: aid)
            var fciNode = SmartCardFileNode("File Control Information", type:.fileControlInformation,  tag: "fci")
            if let asn = ASN1( data: data ) {
                addRecordNodes( asn, to: &fciNode )
            }
            applicationNode.children.append(fciNode)

            // Get processing options (with empty PDOL)
            let commandBytes : [UInt8] = [0x83, 0x00]
            let commandData = Data( commandBytes )
            apdu = APDUCommand(0x80, 0xA8, 0x00, 0x00, commandData, nil )
            response = card.transmit(apdu)

            // Get response nescesary
            if (response.sw1 == 0x61)
            {
                apdu = APDUCommand(0x00, 0xC0, 0x00, 0x00, Data(), response.sw2)
                response = card.transmit(apdu)
            }

            // Not tested - MC applets return 0x6D:
            if response.sw1 == 0x90,
                let data = response.data,
                let template = ASN1( data: data)
            {

                var aip : ASN1?
                var afl : ASN1?

                // Primitive response (Template Format 1)

                let tag = template.tag
                if tag[0] == 0x80
                {
                    let tempAIP = template.value.subdata(in: 0 ..< 2 )
                    aip = ASN1( tag: UInt8( 0x82 ), value: tempAIP)

                    let remainingLength = template.value.count - 2
                    let tempAFL = template.value.subdata(in: 2 ..< remainingLength )
                    afl = ASN1( tag: UInt8( 0x94 ), value: tempAFL)
                }

                // constructed data object response (Template Format 2)
                if template.tag[0] == 0x77
                {
                    aip = template.find(0x82)
                    afl = template.find(0x94)
                }

                var aipaflNode = SmartCardFileNode("Application Interchange Profile - Application File Locator", type: .applicationInterchangeProfile, tag: "aip")

                if let aipafl = aip { // not sure from the code if template or aip should be used..
                    addRecordNodes( aipafl, to: &aipaflNode)
                }
                applicationNode.children.append(aipaflNode)

                // Chop up AFL's
                if let aflValue = afl?.value {
                    for i in stride( from: 0, to: aflValue.count, by: 4 )
                    {
                        let fileLocator = ApplicationFileLocator( data: aflValue.subdata(in: i ..< i+4 ) )
                        applicationFileLocators.append(fileLocator)
                    }

                    for file in applicationFileLocators {
                        let fileNode = readFile( file )
                        applicationNode.children.append( fileNode )
                    }
                }


                //IEnumerable<XElement> tags = tagsDocument.Descendants().Where(el => el.Name == "Tag");
                //foreach (XElement element in tags)
                //{
                //    string tag = element.Attribute("Tag").Value;

                //    // Only try GET_DATA on two byte tags
                //    if (tag.Length == 4)
                //    {
                //        byte p1 = byte.Parse(tag.Substring(0, 2), NumberStyles.HexNumber);
                //        byte p2 = byte.Parse(tag.Substring(2, 2), NumberStyles.HexNumber);

                //        apdu = new APDUCommand(0x80, 0xCA, p1, p2, null, 0);
                //        response = cardReader.Transmit(apdu);

                //        if (response.SW1 == 0x90)
                //        {
                //            Debug.WriteLine(response.ToString());
                //        }
                //    }
                //}

                apdu = APDUCommand(0x80, 0xCA, 0x9f, 0x13, Data(), 0)
                response = card.transmit(apdu)
                Swift.print( response.description)
                apdu = APDUCommand(0x80, 0xCA, 0x9f, 0x17, Data(), 0)
                response = card.transmit(apdu)
                Swift.print( response.description )
                apdu = APDUCommand(0x80, 0xCA, 0x9f, 0x36, Data(), 0)
                response = card.transmit(apdu)
                Swift.print( response.description )
            }
            return applicationNode
        }
        return nil
    }

    func readFile( _ file: ApplicationFileLocator ) -> SmartCardFileNode {

        var r : UInt8 = file.firstRecord// +afl.OfflineRecords;     // We'll read SDA records too
        let lr : UInt8  = file.lastRecord

        let p2 = ((file.SFI << 3) | 4)

        var efNode = SmartCardFileNode( String( format: "Elementary File - %02x", file.SFI ), type: .elementaryFile, tag: file.SFI )
        // applicationNode.children.append(efNode)

        guard let card = card else {
            return efNode
        }

        while (r <= lr)
        {
            var apdu = APDUCommand(0x00, 0xB2, r, p2, Data(), 0x00)
            var response = card.transmit(apdu)

            // Retry with correct length
            if response.sw1 == 0x6C
            {
                apdu = APDUCommand(0x00, 0xB2, r, p2, Data(), response.sw2)
                response = card.transmit(apdu)
            }

            if let data = response.data,
                let efAsn = ASN1( data: data ) {
                let type : NodeType = (r <= file.offlineRecords) ? .sdaRecord : .record
                var recordNode = SmartCardFileNode(String(format:" Record - %02x",  r), type: type,  tag: r)

                efNode.children.append(recordNode)
                addRecordNodes( efAsn, to: &recordNode)
            }

            r += 1
        }
        return efNode
    }

    private func addRecordNodes( _ asn : ASN1, to parent: inout SmartCardFileNode )
    {
        // FIXME: asn.value => Data vs. UInt8 
        var node =  SmartCardFileNode( asn.tag.hexString(), type: .record, tag: asn.value )
        asn.forEach {  addRecordNodes( $0, to: &node)  }

        parent.children.append(node)
    }
}

extension EMVContentController : NSOutlineViewDataSource {
    func nodeForItem( _ item: Any? ) -> SmartCardFileNode {
        if let node = item as? SmartCardFileNode {
            return node
        } else {
            return rootNode
        }
    }

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        let node = nodeForItem( item )
        return node.children.count
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        return nodeForItem( item ).children[index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        return !nodeForItem( item ).children.isEmpty
    }

    /* NOTE: this method is optional for the View Based OutlineView.
     */
    func outlineView(_ outlineView: NSOutlineView, objectValueFor tableColumn: NSTableColumn?, byItem item: Any?) -> Any? {
        return nodeForItem( item ).name
    }

    /* NOTE: Returning nil indicates the item no longer exists, and won't be re-expanded.
     */
    func outlineView(_ outlineView: NSOutlineView, itemForPersistentObject object: Any) -> Any? {
        return object
    }

    /* NOTE: Returning nil indicates that the item's state will not be persisted.
     */
    func outlineView(_ outlineView: NSOutlineView, persistentObjectForItem item: Any?) -> Any? {
        return item
    }
}
