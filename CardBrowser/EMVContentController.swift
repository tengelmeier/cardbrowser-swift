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

struct TagDescriptionElement: Codable {
    let tag, name: String
    let tagDescription: String?

    enum CodingKeys: String, CodingKey {
        case tag, name
        case tagDescription = "description"
    }
}

typealias TagDescription = [TagDescriptionElement]

class EMVContentController : NSViewController {

    enum TokenError : Error {
        case recordNotFound
        case fileNotFound
    }
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
    @IBOutlet var tagView : NSTextField! = nil
    @IBOutlet var dataView : NSTextView! = nil
    @IBOutlet var asciiDataView : NSTextField! = nil
    @IBOutlet var descriptionLabel : NSTextField! = nil

    private var rootNode = SmartCardFileNode( "root", type: .card, tag: "-" )
    private var card : CryptoTokenSmartcard? {
        didSet {
            rootNode.children.removeAll()
            DispatchQueue.main.async {
                self.treeView.reloadData()
            }
            if card === oldValue {
                return
            }

            card?.beginSession{
                success, error in
                // print( "*** Loading Card Content \(self.card!)" )
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

    var tagNames = [Int:TagDescriptionElement]()

    override func viewDidLoad() {

        if let dataUrl = Bundle.main.url(forResource: "EMVTagNames", withExtension: "json" ),
            let descriptionData = try? Data( contentsOf: dataUrl ),
            let descriptions = try? JSONDecoder().decode(TagDescription.self, from: descriptionData ) {
            // tagNames = descriptions

            descriptions.forEach( ) {
                if let tagID = Int( $0.tag, radix: 16 ) {
                    tagNames[tagID] = $0
                }
            }
        }
    }

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

    var currentNode : SmartCardFileNode? {
           didSet {
               tagView.stringValue = ""
               dataView.string = ""
               asciiDataView.stringValue = ""
               descriptionLabel.stringValue = ""

               if let node = currentNode {
                   tagView.stringValue = node.asnTag?.hexString() ?? ""
                   descriptionLabel.stringValue = currentNode?.comment ?? ""
                   if let data = node.tag as? Data {
                       dataView.string = data.hexString(joinedBy: " " )
                       asciiDataView.stringValue = String( data: data, encoding: .ascii ) ?? ""
                   }
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

    func readPaymentSystemEnvironment( _ identifier: String ) -> (SmartCardFileNode, [String])? {
        guard let pse = identifier.data(using: .ascii ),
          let card = card else {
            return nil
        }

        var apdu = APDUCommand( 0x00, 0xA4, 0x04, 0x00, pse, 0 ) // Select APP
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

            var pseNode = SmartCardFileNode( "Application \(identifier)", type: .application, tag: pse )

            var fciNode = SmartCardFileNode("File Control Information", type: .fileControlInformation, tag: "fci" )
            addRecordNodes( tlv, to: &fciNode )
            pseNode.children.append( fciNode )

            // let tlv = ASN1Parser( data )
            if let sfi : UInt8 = tlv.find( 0x88 )?.value[0] {

                var recordNumber : UInt8 = 0x01

                var efDirNode = SmartCardFileNode( "Elementary File - sfi \(sfi)", type: .elementaryFile ,tag: sfi)

                do {
                    while recordNumber < 255
                    {
                        if let parsedRecord = try readRecord(recordNumber: recordNumber, sfi: sfi ) {
                            efDirNode.children.append( parsedRecord.0 )
                            let identifierStrings = parsedRecord.1.map{ $0.hexString() }
                            applicationIdentifiers.append( contentsOf: identifierStrings )
                        }
                        recordNumber += 1
                    }
                } catch let error {

                }
                pseNode.children.append(efDirNode)
                return (pseNode, applicationIdentifiers)
            }
        }
        return nil
    }

    func readRecord( recordNumber: UInt8, sfi: UInt8 ) throws -> (SmartCardFileNode, [Data])? {
        guard let card = card else {
            return nil
        }

        // sfi = short (elementary) file identifier
        // 0 and all bits set are reserved for other uses

        var applicationIdentifiers = [Data]()
        let p2 = ((sfi << 3) | 4) // sfi in high bits, 0x04 indicates to interpret p1 as record number
        var apdu = APDUCommand(0x00, 0xB2, recordNumber, p2, nil, 0x0)

        var response = card.transmit(apdu)
        // Retry with correct length
        if response.sw1 == 0x6C
        {
            apdu = APDUCommand(0x00, 0xB2, recordNumber, p2, Data(), response.sw2)
            response = card.transmit(apdu)
        }

        if response.sw1 == 0x61
        {
            apdu = APDUCommand(0x00, 0xC0, 0x00, 0x00, Data(), response.sw2)
            response = card.transmit(apdu)
        }

        if response.sw1 == 0x6a {
            if response.sw2 == 0x83  {
                throw TokenError.recordNotFound
            } else if response.sw2 == 0x82 {
                throw TokenError.fileNotFound
            }
        }

        if let data = response.data,
            let aef = ASN1( data: data )
        {
            var recordNode = SmartCardFileNode(String(format:"Record %2x", recordNumber), type: .record, tag: recordNumber)

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

    func tryReadAllRecords( ) -> [SmartCardFileNode] {
        var nodes = [SmartCardFileNode]()

        for sfi in 1 ..< 14 {
            var sfiNode = SmartCardFileNode( "Elementary File - SFI:\(sfi)", type:.elementaryFile, tag:sfi )

            do {
                for i in 1 ..< 30 {
                    if let node = try readRecord(recordNumber: UInt8( i ), sfi: UInt8( sfi ) ) {
                        sfiNode.children.append( node.0 )
                    }
                }
            } catch let error {
                
            }
            if !sfiNode.children.isEmpty {
                nodes.append( sfiNode )
            }
        }
        return nodes
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

            // --------------

            // Get processing options (with empty PDOL)
            let commandBytes : [UInt8] = [0x83, 0x00]
            let commandData = Data( commandBytes )
            apdu = APDUCommand(0x80, 0xA8, 0x00, 0x00, commandData, 0 )
            response = card.transmit(apdu)

            // Keep receiving sw1 = 0x67 (wrong length) which should only happen when sizeof( commandBytes != 2 ) ???


            // if response.sw1 == 0x67 {
            //    let alternateCommandData : [UInt8] = [0x83, 0x0B, 00,00, 00, 00, 00, 00, 00, 00, 00, 00, 00]
            //    apdu = APDUCommand(0x80, 0xA8, 0x00, 0x00, Data( alternateCommandData ), 0)
            //     response = card.transmit(apdu)
            // }

            // Get response necessary
            if (response.sw1 == 0x61)
            {
                apdu = APDUCommand(0x00, 0xC0, 0x00, 0x00, Data(), response.sw2)
                response = card.transmit(apdu)
            }

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

                var aipaflNode = SmartCardFileNode("Application Interchange Profile - Application File Locator", type: .applicationInterchangeProfile, tag: data)

                // if let aipafl = template { // not sure from the code if template or aip should be used..
                addRecordNodes( template, to: &aipaflNode)
                // }
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

                /*
                apdu = APDUCommand(0x80, 0xCA, 0x9f, 0x13, Data(), 0)
                response = card.transmit(apdu)
                Swift.print( response.description)
                apdu = APDUCommand(0x80, 0xCA, 0x9f, 0x17, Data(), 0)
                response = card.transmit(apdu)
                Swift.print( response.description )
                apdu = APDUCommand(0x80, 0xCA, 0x9f, 0x36, Data(), 0)
                response = card.transmit(apdu)
                Swift.print( response.description )
                */
            } else {
                // Brute force read all SFIs
                 applicationNode.children.append( contentsOf: tryReadAllRecords( ) )
            }
            return applicationNode
        }
        return nil
    }

    func readFile( _ file: ApplicationFileLocator ) -> SmartCardFileNode {

        var r : UInt8 = file.firstRecord// +afl.OfflineRecords;     // We'll read SDA records too
        let lr : UInt8  = file.lastRecord

        var efNode = SmartCardFileNode( "Elementary File - sfi \(file.SFI)", type: .elementaryFile, tag: file.SFI )
        // applicationNode.children.append(efNode)

        guard let card = card else {
            return efNode
        }

        while (r <= lr)
        {
            do {
                if var recordTuple = try readRecord( recordNumber: UInt8( r ), sfi: file.SFI ) {
                    if r <= file.offlineRecords {
                        recordTuple.0.nodeType = .sdaRecord
                    }
                    efNode.children.append( recordTuple.0 )
                }
            } catch let error {

            }
            r += 1
        }
        return efNode
    }

    private func addRecordNodes( _ asn : ASN1, to parent: inout SmartCardFileNode )
    {
        var title = asn.tag.hexString()
        var comment = ""

        // FIXME: asn.value => Data vs. UInt8
        if let tagValue = asn.tag.intValue,
            let tagDesc = tagNames[tagValue] {
            title = tagDesc.name
            comment = tagDesc.tagDescription ?? ""

        }
        var node =  SmartCardFileNode( title, type: .record, tag: asn.value, commment: comment )
        node.asnTag = asn.tag
        
        asn.forEach {  addRecordNodes( $0, to: &node )  }

        parent.children.append(node)
    }
}


extension EMVContentController : NSOutlineViewDelegate {
    func outlineViewSelectionDidChange(_ notification: Notification) {
        self.currentNode = self.treeView.item(atRow: self.treeView.selectedRow) as? SmartCardFileNode
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
