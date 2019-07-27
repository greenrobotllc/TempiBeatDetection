//
//  BPMViewController.swift
//  TempiBeatDetection
//
//  Created by John Scalo on 4/26/16.
//  Copyright © 2016 John Scalo. See accompanying License.txt for terms.

import UIKit
import AVKit
import AVFoundation

class BPMViewController: UIViewController {

    var lastTime:Double = 0.0
    var lastTimeDiff:Double = 0.0
    var lastLastTimeDiff:Double = 0.0
    var lastLastLastTimeDiff:Double = 0.0
    var lastWasA4Or8:Int = 0
    var lastLastWasA4Or8:Int = 0
    var lastLastLastWasA4Or8:Int = 0
    var last4Time:Double = 0.0
    @IBOutlet weak var bpmLabel: UILabel!
    @IBOutlet weak var range60Button: UIButton!
    @IBOutlet weak var range80Button: UIButton!
    @IBOutlet weak var range100Button: UIButton!
    @IBOutlet weak var range120Button: UIButton!
    
    private let beatDetector: TempiBeatDetector = TempiBeatDetector()

    override func viewDidLoad() {
        super.viewDidLoad()

        UIApplication.shared.isIdleTimerDisabled = true
        
        beatDetector.beatDetectionHandler = {(timeStamp: Double, bpm: Float) in
            self.beatDetected(timeStamp: timeStamp, bpm: bpm)
            
            
        }
        
            //Salsa 180 - 300 beats per minute
            //Merenge 130 - 200 beats per minute
            //Bachata 90 - 200 beats per minute
        //http://www.beatsperminuteonline.com/en/home/bpm-beats-per-minute-reference-for-dance-genres
        
        beatDetector.minTempo = 45
        beatDetector.maxTempo = 150
        
        self.updateButtons()
        
        beatDetector.startFromMic()
    }

    @IBAction func range60Button(sender: UIButton) {
        self.reset(minTempo: 60, maxTempo: 120)
    }
    
    @IBAction func range80Button(sender: UIButton) {
        self.reset(minTempo: 80, maxTempo: 160)
    }

    @IBAction func range100Button(sender: UIButton) {
        self.reset(minTempo: 100, maxTempo: 200)
    }

    @IBAction func range120Button(sender: UIButton) {
        self.reset(minTempo: 120, maxTempo: 240)
    }

    private func reset(minTempo: Float, maxTempo: Float) {
        self.beatDetector.minTempo = minTempo
        self.beatDetector.maxTempo = maxTempo
        self.updateButtons()
        self.restartDetector()
    }
    
    private func updateButtons() {
        self.range60Button!.backgroundColor = UIColor.clear
        self.range60Button!.layer.cornerRadius = self.range60Button!.frame.size.height / 2.0
        self.range60Button!.setTitleColor(UIColor.white, for: UIControl.State.normal)

        self.range80Button.backgroundColor = UIColor.clear
        self.range80Button.layer.cornerRadius = self.range60Button!.frame.size.height / 2.0
        self.range80Button.setTitleColor(UIColor.white, for: UIControl.State.normal)

        self.range100Button.backgroundColor = UIColor.clear
        self.range100Button.layer.cornerRadius = self.range60Button!.frame.size.height / 2.0
        self.range100Button.setTitleColor(UIColor.white, for: UIControl.State.normal)

        self.range120Button.backgroundColor = UIColor.clear
        self.range120Button.layer.cornerRadius = self.range60Button!.frame.size.height / 2.0
        self.range120Button.setTitleColor(UIColor.white, for: UIControl.State.normal)
        
        if self.beatDetector.minTempo == 60.0 {
            self.range60Button!.backgroundColor = UIColor.orange
        } else if self.beatDetector.minTempo == 80.0 {
            self.range80Button.backgroundColor = UIColor.orange
        } else if self.beatDetector.minTempo == 100.0 {
            self.range100Button.backgroundColor = UIColor.orange
        } else if self.beatDetector.minTempo == 120.0 {
            self.range120Button.backgroundColor = UIColor.orange
        }
    }

    private func restartDetector() {
        self.bpmLabel.text = "——"
        self.beatDetector.stop()
        self.beatDetector.startFromMic()
    }
    //var colors = [UIColor.green, .gray, .blue, .red]
    var colors = [UIColor.green, .gray, .gray, .gray,  .gray, .gray, .gray, .gray]
    var theIndex = 1
    private func beatDetected(timeStamp: Double, bpm: Float) {
        DispatchQueue.main.async() {
            //print("beat detected\n\n")
            let timestamp = NSDate().timeIntervalSince1970
            let diff =  timestamp - self.lastTime
            print(self.theIndex, timestamp, diff)
            let total = self.lastLastTimeDiff + self.lastTimeDiff
            let average = total / 2
            
            //diff < self.lastLastLastTimeDiff &&
            //if(diff < self.lastLastTimeDiff && diff < self.lastTimeDiff)
            if(diff < average && diff < self.lastTimeDiff)
            {
                self.lastWasA4Or8=1
            }
            else {
                self.lastWasA4Or8=0
            }
            
            if(self.lastWasA4Or8 == 1 && self.lastLastWasA4Or8 != 1 &&
                self.last4Time + 1.0 < timestamp) {
                self.theIndex = 0
                self.view.backgroundColor = .green

                //self.toggleTorch(on: true)
                print("---It's a 4 or 8---")
                self.theIndex = 0
                self.last4Time = timestamp
                self.lastWasA4Or8 = 0
                self.lastLastWasA4Or8 = 0

            }
            else {
                //self.toggleTorch(on: false)

                self.view.backgroundColor = .gray

            }
            
            self.lastLastLastTimeDiff = self.lastLastTimeDiff
            self.lastLastTimeDiff = self.lastTimeDiff
            self.lastTimeDiff = diff
            self.lastTime = timestamp
            self.lastLastLastWasA4Or8 = self.lastLastWasA4Or8
            self.lastLastWasA4Or8 = self.lastWasA4Or8

//            self.view.backgroundColor = .green
//
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
//                self.view.backgroundColor = .gray
//
//            }
            //self.view.backgroundColor=self.colors[self.theIndex]
            if(self.theIndex == 8) {
                self.theIndex = 1
            }
            else {
                self.theIndex = self.theIndex + 1
            }
            self.bpmLabel.text = String(format: "%0.0f", bpm)
        }
    }
    
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        print("*** Low memory ***");
    }

    func toggleTorch(on: Bool) {
            guard let device = AVCaptureDevice.default(for: AVMediaType.video)
            else {return}

            if device.hasTorch {
                do {
                    try device.lockForConfiguration()

                    if on == true {
                        device.torchMode = .on
                    } else {
                        device.torchMode = .off
                    }

                    device.unlockForConfiguration()
                } catch {
                    print("Torch could not be used")
                }
            } else {
                print("Torch is not available")
            }
        }
    

}

