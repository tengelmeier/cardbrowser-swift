//
//  NodeDetailController.swift
//  CardBrowser
//
//  Created by Thomas Engelmeier on 20.07.19.
//  Copyright © 2019 Thomas Engelmeier. All rights reserved.
//

import Cocoa

class NodeDetailController : NSViewController {
    

    override var representedObject: Any? {
        didSet {
            if let node = representedObject as? SmartCardFileNode {
                currentNode = node
            } else {
                currentNode = nil
            }
        }
    }

   

}
