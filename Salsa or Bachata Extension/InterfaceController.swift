//
//  InterfaceController.swift
//  Salsa or Bachata Extension
//
//  Created by Andy Triboletti on 7/31/19.
//  Copyright © 2019 John Scalo. All rights reserved.
//

import WatchKit
import Foundation
import WatchConnectivity

class InterfaceController: WKInterfaceController, WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("session")
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        print("did receive message on watch")
        salsaOrBachata.setText(message["Value"]! as? String)
    }
    
    @IBOutlet weak var salsaOrBachata: WKInterfaceLabel!
    @IBAction func clicked() {

        let messageToSend = ["Value":"Hello iPhone"]

        session.sendMessage(messageToSend, replyHandler:nil, errorHandler:
         { (error) -> Void in
            print("Watch send gesture failed with error \(error)")
        })
        
        
    }
    
    var session: WCSession!

    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        // Configure interface objects here.
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        if (WCSession.isSupported()) {
            session = WCSession.default
            session.delegate = self as WCSessionDelegate
            session.activate()
        }
        
        super.willActivate()
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }

}
