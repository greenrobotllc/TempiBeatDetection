//
//  TempiBeatDetectorValidation.swift
//  TempiBeatDetection
//
//  Created by John Scalo on 5/1/16.
//  Copyright © 2016 John Scalo. See accompanying License.txt for terms.

import Foundation
import AVFoundation

extension TempiBeatDetector {
    
    func validate() {
//        self.validateStudioSet1()
        self.validateHomeSet1()
//        self.validateThreesSet1()
//        self.validateUtilitySet1()

    }
    
    private func projectURL() -> NSURL {
        let projectPath = "/Users/jscalo/Developer/Tempi/com.github/TempiBeatDetection"
        return NSURL.fileURL(withPath: projectPath) as NSURL
    }

    private func validationSetup() {
        if self.savePlotData {
            let projectURL: NSURL = self.projectURL()
            
            var plotDataURL = projectURL.appendingPathComponent("Peak detection plots")
            plotDataURL = plotDataURL?.appendingPathComponent("\(String(describing: self.currentTestName))-plotData.txt")
            
            var plotMarkersURL = projectURL.appendingPathComponent("Peak detection plots")
            plotMarkersURL = plotMarkersURL?.appendingPathComponent("\(String(describing: self.currentTestName))-plotMarkers.txt")
            
            do {
                try FileManager.default.removeItem(at: plotDataURL!)
                try FileManager.default.removeItem(at: plotMarkersURL!)
            } catch _ { /* normal if file not yet created */ }
            
            //todo re-enable
//            self.plotFFTDataFile = fopen(plotDataURL?.withUnsafeFileSystemRepresentation({ (a?) -> ResultType in
//                    print("OK")
//
//            }), "w")
//
            self.plotFFTDataFile = plotDataURL?.withUnsafeFileSystemRepresentation{
                fopen($0, "w")
                
            }
            self.plotMarkersFile = plotMarkersURL?.withUnsafeFileSystemRepresentation{
                fopen($0, "w")
                
            }
            //self.plotMarkersFile = fopen(plotMarkersURL?.absoluteString, "w")
        }
        
        self.testTotal = 0
        self.testCorrect = 0
    }
    
    private func validationFinish() {
        let result = 100.0 * Float(self.testCorrect) / Float(self.testTotal)
        print(String(format:"[%@] accuracy: %.01f%%\n", self.currentTestName, result));
        self.testSetResults.append(result)
    }
    
    private func testAudio(path: String,
                           label: String,
                           actualTempo: Float,
                           startTime: Double = 0.0, endTime: Double = 0.0,
                           minTempo: Float = 40.0, maxTempo: Float = 240.0,
                           variance: Float = 2.0) {
        
        let projectURL: NSURL = self.projectURL()
        let songURL = projectURL.appendingPathComponent("Test Media/\(path)")
        
        let avAsset: AVURLAsset = AVURLAsset(url: songURL!)
        
        print("Start testing: \(path)")
        
        self.currentTestName = label;
        
        self.startTime = startTime
        self.endTime = endTime
        
        self.minTempo = minTempo
        self.maxTempo = maxTempo
        
        self.setupCommon()
        self.validationSetup()
        
        self.allowedTempoVariance = variance
        
        let assetReader: AVAssetReader
        do {
            assetReader = try AVAssetReader(asset: avAsset)
        } catch let e as NSError {
            print("*** AVAssetReader failed with \(e)")
            return
        }
        
        let settings: [String : AnyObject] = [ AVFormatIDKey : Int(kAudioFormatLinearPCM) as AnyObject,
                                               AVSampleRateKey : self.sampleRate as AnyObject,
                                               AVLinearPCMBitDepthKey : 32 as AnyObject,
                                               AVLinearPCMIsFloatKey : true as AnyObject,
                                               AVNumberOfChannelsKey : 1 as AnyObject ]
        
        let output: AVAssetReaderAudioMixOutput = AVAssetReaderAudioMixOutput.init(audioTracks: avAsset.tracks, audioSettings: settings)
        
        assetReader.add(output)
        
        if !assetReader.startReading() {
            print("assetReader.startReading() failed")
            return
        }
        
        var samplePtr: Int = 0
        
        self.testActualTempo = actualTempo
        
        var queuedSamples: [Float] = [Float]()
        
        repeat {
            var status: OSStatus = 0
            guard let nextBuffer = output.copyNextSampleBuffer() else {
                break
            }
            
            let bufferSampleCnt = CMSampleBufferGetNumSamples(nextBuffer)
            
            var bufferList = AudioBufferList(
                mNumberBuffers: 1,
                mBuffers: AudioBuffer(
                    mNumberChannels: 1,
                    mDataByteSize: 4,
                    mData: nil))
            
            var blockBuffer: CMBlockBuffer?
            
            status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(nextBuffer,
                                                                             bufferListSizeNeededOut: nil,
                                                                             bufferListOut: &bufferList,
                                                                             bufferListSize: MemoryLayout<UInt32>.size,
                                                                             blockBufferAllocator: nil,
                                                                             blockBufferMemoryAllocator: nil,
                                                                             flags: kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
                                                                             blockBufferOut: &blockBuffer)
            
            if status != 0 {
                print("*** CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer failed with error \(status)")
                break
            }
            
            // Move samples from mData into our native [Float] format.
            // (There's probably an better way to do this using UnsafeBufferPointer but I couldn't make it work.)
            
            
////todo re-enable
//            /for i in 0..<bufferSampleCnt {
//                let ptr = UnsafePointer<Float>(bufferList.mBuffers.mData)
//                let newPtr = ptr + i
//                let sample = unsafeBitCast(newPtr.memory, Float.self)
//                queuedSamples.append(sample)
//            }

            
            
            // We have a big buffer of audio (whatever CoreAudio decided to give us).
            // Now iterate over the buffer, sending a chunkSize's (e.g. 4096 samples) worth of data to the analyzer and then
            // shifting by hopSize (e.g. 132 samples) after each iteration. If there's not enough data in the buffer (bufferSampleCnt < chunkSize),
            // then add the data to the queue and get the next buffer.

            while queuedSamples.count >= self.chunkSize {
                let timeStamp: Double = Double(samplePtr) / Double(self.sampleRate)
                
                if self.endTime > 0.01 {
                    if timeStamp < self.startTime || timeStamp > self.endTime {
                        queuedSamples.removeFirst(self.hopSize)
                        samplePtr += self.hopSize
                        continue
                    }
                }
                
                let subArray: [Float] = Array(queuedSamples[0..<self.chunkSize])
                
                self.analyzeAudioChunk(timeStamp: timeStamp, samples: subArray)
                
                samplePtr += self.hopSize
                queuedSamples.removeFirst(self.hopSize)
            }
            
        } while true
        
        print("Finished testing: \(path)")
        
        if self.savePlotData {
            fclose(self.plotFFTDataFile)
            fclose(self.plotMarkersFile)
        }
        
        self.validationFinish()
    }
    
    private func testSetSetupForSetName(setName: String) {
        print("Starting validation set \(setName)");
        self.currentTestSetName = setName
        self.testSetResults = [Float]()
    }
    
    private func testSetFinish() {
        let mean: Float = tempi_mean(a: self.testSetResults)
        print(String(format:"Validation set [%@] accuracy: %.01f%%\n", self.currentTestSetName, mean));
    }
    
    public func oneOffTest() {
        self.testSetSetupForSetName(setName: "oneOff")

        self.testAudio(path: "Studio/Learn To Fly.mp3",
                       label: "learn-to-fly",
                       actualTempo: 136,
                       startTime: 0, endTime: 15,
                       minTempo: 80, maxTempo: 160,
                       variance: 2)
        
        self.testSetFinish()
    }
    
    private func validateStudioSet1 () {
        self.testSetSetupForSetName(setName: "studioSet1")
        
        self.testAudio(path: "Studio/Skinny Sweaty Man.mp3",
                       label: "skinny-sweaty-man",
                       actualTempo: 141,
                       startTime: 0, endTime: 15,
                       minTempo: 80, maxTempo: 160,
                       variance: 3)
        
        self.testAudio(path: "Studio/Satisfaction.mp3",
                       label: "satisfaction",
                       actualTempo: 137,
                       startTime: 0, endTime: 20,
                       minTempo: 80, maxTempo: 160,
                       variance: 2.5)

        self.testAudio(path: "Studio/Louie, Louie.mp3",
                       label: "louie-louie",
                       actualTempo: 120,
                       startTime: 0, endTime: 15,
                       minTempo: 60, maxTempo: 120,
                       variance: 3)

        self.testAudio(path: "Studio/Learn To Fly.mp3",
                       label: "learn-to-fly",
                       actualTempo: 136,
                       startTime: 0, endTime: 15,
                       minTempo: 80, maxTempo: 160,
                       variance: 2)

        self.testAudio(path: "Studio/HBFS.mp3",
                       label: "harder-better-faster-stronger",
                       actualTempo: 123,
                       startTime: 0, endTime: 15,
                       minTempo: 80, maxTempo: 160,
                       variance: 2)

        self.testAudio(path: "Studio/Waving Flag.mp3",
                       label: "waving-flag",
                       actualTempo: 76,
                       startTime: 0, endTime: 15,
                       minTempo: 60, maxTempo: 120,
                       variance: 2)

        self.testAudio(path: "Studio/Back in Black.mp3",
                       label: "back-in-black",
                       actualTempo: 90,
                       startTime: 0, endTime: 15,
                       minTempo: 60, maxTempo: 120,
                       variance: 2)

        self.testSetFinish()
    }
    
    private func validateHomeSet1 () {
        self.testSetSetupForSetName(setName: "homeSet1")
        
        self.testAudio(path: "Home/AG-Blackbird-1.mp3",
                       label: "ag-blackbird1",
                       actualTempo: 94,
                       minTempo: 60, maxTempo: 120,
                       variance: 3)

        self.testAudio(path: "Home/AG-Blackbird-2.mp3",
                       label: "ag-blackbird2",
                       actualTempo: 95,
                       minTempo: 60, maxTempo: 120,
                       variance: 3)
        
        self.testAudio(path: "Home/AG-Sunset Road-116-1.mp3",
                       label: "ag-sunsetroad1",
                       actualTempo: 116,
                       minTempo: 80, maxTempo: 160,
                       variance: 2)
        
        self.testAudio(path: "Home/AG-Sunset Road-116-2.mp3",
                       label: "ag-sunsetroad2",
                       actualTempo: 116,
                       minTempo: 80, maxTempo: 160,
                       variance: 2)
        
        self.testAudio(path: "Home/Possum-1.mp3",
                       label: "possum1",
                       actualTempo: 79,
                       minTempo: 60, maxTempo: 120,
                       variance: 2)
        
        self.testAudio(path: "Home/Possum-2.mp3",
                       label: "possum2",
                       actualTempo: 81,
                       minTempo: 60, maxTempo: 120,
                       variance: 3)
        
        self.testAudio(path: "Home/Hard Top-1.mp3",
                       label: "hard-top1",
                       actualTempo: 133,
                       minTempo: 80, maxTempo: 160,
                       variance: 2)
        
        self.testAudio(path: "Home/Hard Top-2.mp3",
                       label: "hard-top2",
                       actualTempo: 146,
                       minTempo: 80, maxTempo: 160,
                       variance: 2)
        
        self.testAudio(path: "Home/Definitely Delicate-1.mp3",
                       label: "delicate1",
                       actualTempo: 75,
                       minTempo: 60, maxTempo: 120,
                       variance: 3)
        
        self.testAudio(path: "Home/Wildwood Flower-1.mp3",
                       label: "wildwood1",
                       actualTempo: 95,
                       minTempo: 80, maxTempo: 160,
                       variance: 3)
        
        self.testAudio(path: "Home/Wildwood Flower-2.mp3",
                       label: "wildwood2",
                       actualTempo: 148,
                       minTempo: 80, maxTempo: 160,
                       variance: 3)
        
        self.testSetFinish()
    }
    
    private func validateThreesSet1 () {
        self.testSetSetupForSetName(setName: "threesSet1")

        self.testAudio(path: "Threes/Norwegian Wood.mp3",
                       label: "norwegian-wood",
                       actualTempo: 180,
                       startTime: 0, endTime: 0,
                       minTempo: 100, maxTempo: 200,
                       variance: 3)

        self.testAudio(path: "Threes/Drive In Drive Out.mp3",
                       label: "drive-in-drive-out",
                       actualTempo: 81,
                       startTime: 0, endTime: 0,
                       minTempo: 60, maxTempo: 120,
                       variance: 2)
        
        self.testAudio(path: "Threes/Oh How We Danced.mp3",
                       label: "oh-how-we-danced",
                       actualTempo: 180,
                       startTime: 0, endTime: 20,
                       minTempo: 100, maxTempo: 200,
                       variance: 2)
        
        self.testAudio(path: "Threes/Texas Flood.mp3",
                       label: "texas-flood",
                       actualTempo: 60,
                       startTime: 0, endTime: 20,
                       minTempo: 40, maxTempo: 120,
                       variance: 2)
        
        self.testAudio(path: "Threes/Brahms Lullaby.mp3",
                       label: "brahms-lullaby",
                       actualTempo: 70,
                       startTime: 0, endTime: 15,
                       minTempo: 60, maxTempo: 120,
                       variance: 2)
        
        
        self.testSetFinish()
    }
    
    private func validateUtilitySet1 () {
        self.testSetSetupForSetName(setName: "utilitySet1")

        self.testAudio(path: "Utility/metronome-88.mp3",
                       label: "metronome-88",
                       actualTempo: 88,
                       startTime: 0, endTime: 10,
                       minTempo: 40, maxTempo: 240,
                       variance: 1)

        self.testAudio(path: "Utility/metronome-126.mp3",
                       label: "metronome-126",
                       actualTempo: 126,
                       startTime: 0, endTime: 15,
                       minTempo: 40, maxTempo: 240,
                       variance: 1)

        self.testAudio(path: "Utility/1sTones.wav",
                       label: "1s-tones",
                       actualTempo: 60,
                       startTime: 0, endTime: 10,
                       minTempo: 40, maxTempo: 240,
                       variance: 1)

        self.testSetFinish()
    }
}
